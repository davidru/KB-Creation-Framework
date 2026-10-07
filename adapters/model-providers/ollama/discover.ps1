# Title: discover.ps1 — Ollama local model discovery.
# Purpose: List locally pulled Ollama models in Model Registry discovery format.
# Inputs: -OutPath plus optional OLLAMA_ENDPOINT environment variable.
# Outputs: Pretty JSON array of discovered model descriptors at -OutPath.
# Exit codes: 0 success or graceful no-models; 1 output-write or unexpected transform failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutPath
)

$ErrorActionPreference = 'Stop'

function Get-OllamaEndpoint {
    $endpoint = $env:OLLAMA_ENDPOINT ?? 'http://localhost:11434'
    if ([string]::IsNullOrWhiteSpace($endpoint)) { $endpoint = 'http://localhost:11434' }
    return $endpoint.Trim().TrimEnd('/')
}

function Write-JsonOutput {
    param($Data, [string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    ConvertTo-Json -InputObject @($Data) -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-HttpErrorMessage {
    param($ErrorRecord)
    $detail = [string]$ErrorRecord.ErrorDetails.Message
    if (-not [string]::IsNullOrWhiteSpace($detail)) { return $detail }
    if ($ErrorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.Exception.Message)) { return $ErrorRecord.Exception.Message }
    return [string]$ErrorRecord
}

function Infer-Family {
    param([string]$RawModelId)
    if ([string]::IsNullOrWhiteSpace($RawModelId)) { return 'other' }
    $modelKey = (($RawModelId.Trim().ToLowerInvariant()) -split '/')[-1]
    switch -Wildcard ($modelKey) {
        'claude*'      { return 'anthropic' }
        'gpt*'         { return 'openai' }
        'o1*'          { return 'openai' }
        'gemini*'      { return 'google' }
        'gemma*'       { return 'google' }
        'llama*'       { return 'meta-llama' }
        'qwen*'        { return 'qwen' }
        'mistral*'     { return 'mistral' }
        'deepseek*'    { return 'deepseek' }
        'phi*'         { return 'microsoft' }
        'mai-code-*'   { return 'internal-microsoft' }
        'mai-*'        { return 'internal-microsoft' }
        'goldeneye*'   { return 'internal-microsoft' }
        default        { return 'other' }
    }
}

function Normalize-FamilyHint {
    param([string]$RawFamily, [string]$ModelId)
    if ([string]::IsNullOrWhiteSpace($RawFamily)) { return (Infer-Family -RawModelId $ModelId) }
    switch -Wildcard ($RawFamily.Trim().ToLowerInvariant()) {
        'llama*'    { return 'meta-llama' }
        'qwen*'     { return 'qwen' }
        'mistral*'  { return 'mistral' }
        'gemma*'    { return 'google' }
        'deepseek*' { return 'deepseek' }
        'phi*'      { return 'microsoft' }
        default     { return $RawFamily.Trim().ToLowerInvariant() }
    }
}

function Test-ToolCapableModel {
    param([string]$ModelId)
    if ([string]::IsNullOrWhiteSpace($ModelId)) { return $false }
    $name = $ModelId.ToLowerInvariant()
    return ($name -match '(^|/)llama3\.[1-9]' -or
            $name -match '(^|/)qwen2\.5' -or
            $name -match '(^|/)qwen3' -or
            $name -match '(^|/)mistral-large')
}

function Format-ModelSize {
    param($Bytes)
    if ($null -eq $Bytes) { return $null }
    try { $value = [double]$Bytes } catch { return [string]$Bytes }
    if ($value -ge 1TB) { return ('{0:N2} TB' -f ($value / 1TB)) }
    if ($value -ge 1GB) { return ('{0:N2} GB' -f ($value / 1GB)) }
    if ($value -ge 1MB) { return ('{0:N2} MB' -f ($value / 1MB)) }
    return ('{0:N0} bytes' -f $value)
}

function ConvertTo-IntegerOrNull {
    param($Value)
    if ($null -eq $Value) { return $null }
    try { return [int]$Value } catch { return $null }
}

function Get-ContextWindowFromShowResponse {
    param($ShowResponse)
    if ($null -eq $ShowResponse) { return $null }

    foreach ($containerName in @('model_info','details')) {
        $container = $ShowResponse.PSObject.Properties[$containerName]
        if (-not $container) { continue }
        foreach ($prop in $container.Value.PSObject.Properties) {
            if ($prop.Name -match '(?i)(context[_\.]length|num_ctx|n_ctx)$') {
                $parsed = ConvertTo-IntegerOrNull -Value $prop.Value
                if ($parsed) { return $parsed }
            }
        }
    }

    $parametersProp = $ShowResponse.PSObject.Properties['parameters']
    if ($parametersProp -and $parametersProp.Value) {
        $parametersText = [string]$parametersProp.Value
        if ($parametersText -match '(?im)^\s*(?:num_ctx|n_ctx|context_length)\s+([0-9]+)\s*$') { return [int]$matches[1] }
    }

    return $null
}

function Estimate-ContextWindow {
    param([string]$ModelId, [string]$ParameterSize)
    $name = if ($ModelId) { $ModelId.ToLowerInvariant() } else { '' }
    if ($name -match 'llama3\.[1-9]|qwen2\.5|qwen3|mistral-large') { return 131072 }
    if ($name -match 'deepseek-coder-v2') { return 163840 }
    if ($name -match 'mistral|mixtral|deepseek|codellama') { return 32768 }
    if ($ParameterSize -match '(?i)(70b|72b|65b|34b|32b)') { return 32768 }
    return 8192
}

function Get-ModelContextWindow {
    param([string]$Endpoint, [string]$ModelId, [string]$ParameterSize)
    $getError = $null
    try {
        $encoded = [System.Uri]::EscapeDataString($ModelId)
        $show = Invoke-RestMethod -Uri "$Endpoint/api/show?name=$encoded" -Method Get -TimeoutSec 20
        $context = Get-ContextWindowFromShowResponse -ShowResponse $show
        if ($context) { return $context }
    } catch {
        $getError = $_
    }

    try {
        $showBody = [ordered]@{ name = $ModelId }
        $show = Invoke-RestMethod -Uri "$Endpoint/api/show" -Method Post -Body (ConvertTo-Json -InputObject $showBody -Depth 5) -ContentType 'application/json' -TimeoutSec 20
        $context = Get-ContextWindowFromShowResponse -ShowResponse $show
        if ($context) { return $context }
    } catch {
        $detail = Get-HttpErrorMessage -ErrorRecord $_
        if ($getError) { $detail = "GET: $(Get-HttpErrorMessage -ErrorRecord $getError); POST: $detail" }
        Write-Warning "Could not read Ollama metadata for '$ModelId'; using estimated context window. Details: $detail"
    }

    return (Estimate-ContextWindow -ModelId $ModelId -ParameterSize $ParameterSize)
}

try {
    $endpoint = Get-OllamaEndpoint
    try {
        $tags = Invoke-RestMethod -Uri "$endpoint/api/tags" -Method Get -TimeoutSec 10
    } catch {
        Write-Warning "No models discovered: Ollama is not running or is unreachable at '$endpoint'. Details: $(Get-HttpErrorMessage -ErrorRecord $_)"
        Write-JsonOutput -Data @() -Path $OutPath
        exit 0
    }

    $models = @($tags.models)
    $results = foreach ($model in $models) {
        $name = [string]$model.name
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $details = $model.details
        $rawFamily = if ($details -and $details.PSObject.Properties['family']) { [string]$details.family } else { '' }
        $parameterSize = if ($details -and $details.PSObject.Properties['parameter_size']) { [string]$details.parameter_size } else { '' }
        $quantization = if ($details -and $details.PSObject.Properties['quantization_level']) { [string]$details.quantization_level } else { '' }
        $capabilities = @('text')
        if (Test-ToolCapableModel -ModelId $name) { $capabilities += 'tools' }

        $notesParts = New-Object System.Collections.Generic.List[string]
        $sizeText = Format-ModelSize -Bytes $model.size
        if ($sizeText) { $notesParts.Add("size=$sizeText") | Out-Null }
        if ($parameterSize) { $notesParts.Add("parameters=$parameterSize") | Out-Null }
        if ($quantization) { $notesParts.Add("quantization=$quantization") | Out-Null }

        [ordered]@{
            model_id = $name
            family_hint = (Normalize-FamilyHint -RawFamily $rawFamily -ModelId $name)
            context_window = (Get-ModelContextWindow -Endpoint $endpoint -ModelId $name -ParameterSize $parameterSize)
            capabilities = $capabilities
            pricing = [ordered]@{
                prompt_per_million = 0
                completion_per_million = 0
            }
            top_provider = 'ollama-local'
            notes = ($notesParts -join '; ')
        }
    }

    Write-JsonOutput -Data @($results) -Path $OutPath
    if (@($results).Count -eq 0) { Write-Host "No Ollama models available at '$endpoint'. Pull one with: ollama pull <model>" }
    exit 0
} catch {
    Write-Error -ErrorAction Continue "Ollama discovery failed unexpectedly. Details: $(Get-HttpErrorMessage -ErrorRecord $_)"
    exit 1
}
