# Title: dispatch.ps1 — Azure Foundry chat-completions dispatcher.
# Purpose: Send one framework prompt to an Azure Foundry deployment.
# Inputs: -ModelId deployment name, -PromptPath, -OutPath, token controls.
# Outputs: Normalized JSON result written to -OutPath.
# Exit codes: 0 success; 1 validation, auth, network, or API error.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ModelId,
    [Parameter(Mandatory=$true)][string]$PromptPath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [Parameter(Mandatory=$false)][int]$MaxTokens = 4096,
    [Parameter(Mandatory=$false)][double]$Temperature = 1.0
)

$ErrorActionPreference = 'Stop'

function Get-RequiredEnv {
    param([Parameter(Mandatory=$true)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable is not set: env:$Name"
    }
    return $value
}

function Get-ApiVersion {
    $value = [Environment]::GetEnvironmentVariable('AZURE_FOUNDRY_API_VERSION')
    if ([string]::IsNullOrWhiteSpace($value)) { return '2024-10-21' }
    return $value
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory=$true)]$Data,
        [Parameter(Mandatory=$true)][string]$Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    ConvertTo-Json -InputObject $Data -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Get-HttpStatusCode {
    param([Parameter(Mandatory=$true)]$ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response -or $null -eq $response.StatusCode) { return $null }
    try { return [int]$response.StatusCode } catch { return [int]$response.StatusCode.value__ }
}

function Get-ErrorDetails {
    param([Parameter(Mandatory=$true)]$ErrorRecord)

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }
    return $ErrorRecord.Exception.Message
}

function Invoke-FoundryRequest {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][hashtable]$Headers,
        [Parameter(Mandatory=$true)][string]$Body
    )

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            return Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $Body
        } catch {
            $statusCode = Get-HttpStatusCode -ErrorRecord $_
            if ($statusCode -eq 429 -and $attempt -lt $maxAttempts) {
                $delaySeconds = [int][math]::Pow(2, ($attempt - 1))
                Start-Sleep -Seconds $delaySeconds
                continue
            }
            throw
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $PromptPath -PathType Leaf)) {
        throw "PromptPath not found: $PromptPath"
    }

    $endpoint = (Get-RequiredEnv -Name 'AZURE_FOUNDRY_ENDPOINT').TrimEnd('/')
    $apiKey = Get-RequiredEnv -Name 'AZURE_FOUNDRY_API_KEY'
    $apiVersion = Get-ApiVersion
    $deployment = [System.Uri]::EscapeDataString($ModelId)
    $uri = "$endpoint/openai/deployments/$deployment/chat/completions?api-version=$apiVersion"
    $prompt = Get-Content -LiteralPath $PromptPath -Raw -Encoding utf8

    $body = [ordered]@{
        messages = @(
            [ordered]@{
                role = 'user'
                content = $prompt
            }
        )
        max_tokens = $MaxTokens
        temperature = $Temperature
    }
    $response = Invoke-FoundryRequest -Uri $uri -Headers @{ 'api-key' = $apiKey } -Body ($body | ConvertTo-Json -Depth 20)

    $content = $null
    if ($response.choices -and $response.choices.Count -gt 0 -and $response.choices[0].message) {
        $content = $response.choices[0].message.content
    }
    if ($null -eq $content) { $content = '' }
    if ($content -isnot [string]) { $content = $content | ConvertTo-Json -Depth 20 -Compress }

    $result = [ordered]@{
        status = 'success'
        adapter = 'azure-foundry'
        model_id = $ModelId
        completion = $content
        usage = $response.usage
    }
    Write-JsonFile -Data $result -Path $OutPath
    exit 0
} catch {
    $errorResult = [ordered]@{
        status = 'error'
        adapter = 'azure-foundry'
        model_id = $ModelId
        error = [ordered]@{
            message = $_.Exception.Message
            status_code = Get-HttpStatusCode -ErrorRecord $_
            details = Get-ErrorDetails -ErrorRecord $_
        }
    }

    try { Write-JsonFile -Data $errorResult -Path $OutPath } catch { }
    [Console]::Error.WriteLine(($errorResult | ConvertTo-Json -Depth 20))
    exit 1
}
