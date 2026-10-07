# Title: dispatch.ps1 — OpenRouter chat-completions dispatcher.
# Purpose: Send one prompt to one OpenRouter model through the chat API.
# Inputs: -ModelId, -PromptPath, -OutPath, optional token/retry controls.
# Outputs: Pretty JSON success/error envelope at -OutPath and on failures stdout.
# Exit codes: 0 completion succeeded; 1 validation, HTTP, or write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ModelId,
    [Parameter(Mandatory=$true)][string]$PromptPath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [Parameter(Mandatory=$false)][int]$MaxTokens = 4096,
    [Parameter(Mandatory=$false)][double]$Temperature = 1.0,
    [Parameter(Mandatory=$false)][int]$MaxRetries = 3
)

$ErrorActionPreference = 'Stop'
$OpenRouterBaseUri = 'https://openrouter.ai/api/v1'

function Get-ObjectProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function ConvertTo-DecimalOrNull {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $text = [string]$Value
    $parsed = [decimal]0
    if ([decimal]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        return $parsed
    }
    return $null
}

function Write-JsonOutput {
    param($Data, [string]$Path)
    $json = ConvertTo-Json -InputObject $Data -Depth 24
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Classify-HttpError {
    # Maps an OpenRouter HTTP status code to an error_type tag + actionable remediation.
    # Returns @{ error_type=...; remediation=...; retriable=$true|$false }
    param([int]$Status)
    switch ($Status) {
        401 { return @{ error_type='auth_failure'; remediation='OPENROUTER_API_KEY is missing, invalid, or revoked. Verify with `([Environment]::GetEnvironmentVariable("OPENROUTER_API_KEY","User")).Length` and regenerate at https://openrouter.ai/keys if needed.'; retriable=$false } }
        402 { return @{ error_type='insufficient_credits'; remediation='OpenRouter account is out of credits. Either (a) add credits at https://openrouter.ai/credits and re-dispatch this phase, OR (b) switch the affected role to a handle from a different provider (Copilot CLI = usage-based via host; Azure Foundry = pre-paid via deployment; Ollama = free local) via the Mid-Build Override Flow in `prompts/00a-model-selection.md`.'; retriable=$false } }
        403 { return @{ error_type='forbidden_or_model_unavailable'; remediation='OpenRouter denied access to this model. Either the account lacks permission (check tier at https://openrouter.ai/settings) or the model was deprecated. Pick a different handle.'; retriable=$false } }
        404 { return @{ error_type='model_not_found'; remediation='OpenRouter does not recognize the requested model_id. Re-run `Discover-OpenRouterCategories.ps1` to refresh available models, then update the handle in `model-registry.yaml`.'; retriable=$false } }
        429 { return @{ error_type='rate_limit'; remediation='OpenRouter rate-limited the request. Adapter retried with exponential backoff up to 3 attempts; further retries blocked by adapter. Reduce parallel dispatch concurrency or wait.'; retriable=$true } }
        default {
            if ($Status -ge 500 -and $Status -lt 600) { return @{ error_type='upstream_error'; remediation="OpenRouter returned HTTP $Status (upstream provider failure). Retry the phase shortly; if persistent, switch to a handle that doesn't depend on this upstream provider."; retriable=$true } }
            return @{ error_type='other'; remediation="HTTP $Status. See error message for details. If unclear, file an issue with the full error JSON."; retriable=$false }
        }
    }
}

function Write-ErrorJson {
    param([string]$Message, [string]$Path, [int]$ExitCode = 1, [string]$ErrorType = 'other', [string]$Remediation = '', [int]$HttpStatus = 0)
    $payload = [ordered]@{
        status = 'error'
        adapter = 'openrouter'
        model_id = $ModelId
        error_type = $ErrorType
        error_message = $Message
        remediation = $Remediation
        http_status = $HttpStatus
    }
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        Write-JsonOutput -Data $payload -Path $Path
    }
    Write-Output (ConvertTo-Json -InputObject $payload -Depth 10)
    exit $ExitCode
}

function Get-HttpStatusCode {
    param($ErrorRecord)
    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) { return $null }
    $statusCode = $response.StatusCode
    if ($null -eq $statusCode) { return $null }
    if ($statusCode -is [int]) { return [int]$statusCode }
    if ($statusCode.PSObject.Properties['value__']) { return [int]$statusCode.value__ }
    try { return [int]$statusCode } catch { return $null }
}

function Get-HttpErrorMessage {
    param($ErrorRecord)
    $status = Get-HttpStatusCode -ErrorRecord $ErrorRecord
    $details = $ErrorRecord.ErrorDetails.Message
    if (-not [string]::IsNullOrWhiteSpace($details)) {
        if ($null -ne $status) { return "HTTP ${status}: $details" }
        return $details
    }
    if ($null -ne $status) { return "HTTP ${status}: $($ErrorRecord.Exception.Message)" }
    return $ErrorRecord.Exception.Message
}

function Invoke-OpenRouterChat {
    param([hashtable]$Headers, [string]$JsonBody, [int]$Retries)
    $attempt = 0
    while ($true) {
        try {
            return Invoke-RestMethod -Uri "$OpenRouterBaseUri/chat/completions" -Method Post -Headers $Headers -ContentType 'application/json' -Body $JsonBody
        } catch {
            $status = Get-HttpStatusCode -ErrorRecord $_
            if ($status -eq 429 -and $attempt -lt $Retries) {
                $delaySeconds = [int][Math]::Min(60, [Math]::Pow(2, $attempt))
                Write-Warning "OpenRouter returned 429 rate limit; retrying in $delaySeconds second(s) (retry $($attempt + 1) of $Retries)."
                Start-Sleep -Seconds $delaySeconds
                $attempt++
                continue
            }
            throw
        }
    }
}

function Get-ModelMetadata {
    param([string]$RequestedModelId)
    try {
        $response = Invoke-RestMethod -Uri "$OpenRouterBaseUri/models" -Method Get
        $models = @()
        if ($response.PSObject.Properties['data']) { $models = @($response.data) }
        elseif ($response -is [System.Collections.IEnumerable] -and -not ($response -is [string])) { $models = @($response) }
        else { $models = @($response) }
        return @($models | Where-Object { [string](Get-ObjectProperty -Object $_ -Name 'id') -eq $RequestedModelId } | Select-Object -First 1)[0]
    } catch {
        return $null
    }
}

function ConvertTo-CompletionText {
    param($Response)
    $choices = @(Get-ObjectProperty -Object $Response -Name 'choices')
    if ($choices.Count -eq 0) { return '' }
    $choice = $choices[0]
    $message = Get-ObjectProperty -Object $choice -Name 'message'
    $content = Get-ObjectProperty -Object $message -Name 'content'
    if ($null -eq $content) { $content = Get-ObjectProperty -Object $choice -Name 'text' }
    if ($null -eq $content) { return '' }
    if ($content -is [string]) { return $content }
    if ($content -is [System.Collections.IEnumerable]) {
        $parts = @($content | ForEach-Object {
            if ($_ -is [string]) { $_ }
            elseif ($_.PSObject.Properties['text']) { [string]$_.text }
            elseif ($_.PSObject.Properties['content']) { [string]$_.content }
        })
        return ($parts -join '')
    }
    return [string]$content
}

function Get-UsageObject {
    param($Response)
    $usage = Get-ObjectProperty -Object $Response -Name 'usage'
    return [ordered]@{
        prompt_tokens = Get-ObjectProperty -Object $usage -Name 'prompt_tokens'
        completion_tokens = Get-ObjectProperty -Object $usage -Name 'completion_tokens'
        total_tokens = Get-ObjectProperty -Object $usage -Name 'total_tokens'
    }
}

function Get-CostEstimate {
    param($Usage, $Metadata)
    $pricing = Get-ObjectProperty -Object $Metadata -Name 'pricing'
    $promptPerToken = ConvertTo-DecimalOrNull -Value (Get-ObjectProperty -Object $pricing -Name 'prompt')
    $completionPerToken = ConvertTo-DecimalOrNull -Value (Get-ObjectProperty -Object $pricing -Name 'completion')
    $promptTokens = ConvertTo-DecimalOrNull -Value $Usage.prompt_tokens
    $completionTokens = ConvertTo-DecimalOrNull -Value $Usage.completion_tokens

    $promptCost = $null
    $completionCost = $null
    $totalCost = $null
    if ($null -ne $promptPerToken -and $null -ne $promptTokens) { $promptCost = $promptPerToken * $promptTokens }
    if ($null -ne $completionPerToken -and $null -ne $completionTokens) { $completionCost = $completionPerToken * $completionTokens }
    if ($null -ne $promptCost -or $null -ne $completionCost) { $totalCost = ($promptCost ?? 0) + ($completionCost ?? 0) }

    return [ordered]@{
        currency = 'USD'
        prompt = if ($null -ne $promptCost) { [double]$promptCost } else { $null }
        completion = if ($null -ne $completionCost) { [double]$completionCost } else { $null }
        total = if ($null -ne $totalCost) { [double]$totalCost } else { $null }
        pricing = [ordered]@{
            prompt_per_token = if ($null -ne $promptPerToken) { [double]$promptPerToken } else { $null }
            completion_per_token = if ($null -ne $completionPerToken) { [double]$completionPerToken } else { $null }
            prompt_per_million = if ($null -ne $promptPerToken) { [double]($promptPerToken * 1000000) } else { $null }
            completion_per_million = if ($null -ne $completionPerToken) { [double]($completionPerToken * 1000000) } else { $null }
        }
    }
}

function Get-ServedProvider {
    param($Response, $Metadata)
    foreach ($path in @(
        @('provider'),
        @('top_provider'),
        @('model_provider'),
        @('route','provider')
    )) {
        $value = $Response
        foreach ($part in $path) { $value = Get-ObjectProperty -Object $value -Name $part }
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return $value }
    }
    return Get-ObjectProperty -Object $Metadata -Name 'top_provider'
}

try {
    if ($MaxTokens -lt 1) { Write-ErrorJson -Message 'MaxTokens must be greater than 0.' -Path $OutPath }
    if ($MaxRetries -lt 0) { Write-ErrorJson -Message 'MaxRetries cannot be negative.' -Path $OutPath }
    if (-not (Test-Path -LiteralPath $PromptPath -PathType Leaf)) { Write-ErrorJson -Message "PromptPath not found: $PromptPath" -Path $OutPath }

    $apiKey = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY')
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-ErrorJson -Message 'OPENROUTER_API_KEY is not set. Set it before using the OpenRouter dispatch adapter.' -Path $OutPath
    }

    $prompt = Get-Content -LiteralPath $PromptPath -Raw -Encoding UTF8
    $headers = @{
        Authorization = "Bearer $apiKey"
    }
    $body = [ordered]@{
        model = $ModelId
        messages = @(
            [ordered]@{
                role = 'user'
                content = $prompt
            }
        )
        max_tokens = $MaxTokens
        temperature = $Temperature
    }
    $jsonBody = ConvertTo-Json -InputObject $body -Depth 12

    $response = Invoke-OpenRouterChat -Headers $headers -JsonBody $jsonBody -Retries $MaxRetries
    $metadata = Get-ModelMetadata -RequestedModelId $ModelId
    $usage = Get-UsageObject -Response $response
    $result = [ordered]@{
        status = 'success'
        adapter = 'openrouter'
        model_id = $ModelId
        completion = ConvertTo-CompletionText -Response $response
        usage = $usage
        cost_estimate = Get-CostEstimate -Usage $usage -Metadata $metadata
        top_provider = Get-ServedProvider -Response $response -Metadata $metadata
    }

    Write-JsonOutput -Data $result -Path $OutPath
    exit 0
} catch {
    $status = Get-HttpStatusCode -ErrorRecord $_
    $msg = Get-HttpErrorMessage -ErrorRecord $_
    if ($status) {
        $cls = Classify-HttpError -Status $status
        Write-ErrorJson -Message $msg -Path $OutPath -ErrorType $cls.error_type -Remediation $cls.remediation -HttpStatus $status
    } else {
        Write-ErrorJson -Message $msg -Path $OutPath -ErrorType 'network_or_unknown' -Remediation 'No HTTP status returned. Likely network connectivity issue (DNS, firewall, proxy) or OpenRouter outage. Check https://status.openrouter.ai/ and operator network.'
    }
}
