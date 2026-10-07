# Title: dispatch.ps1 — Ollama provider prompt dispatcher.
# Purpose: Send one prompt file to a locally pulled Ollama model.
# Inputs: -ModelId, -PromptPath, -OutPath, optional -MaxTokens and -Temperature.
# Outputs: Pretty JSON response envelope at -OutPath.
# Exit codes: 0 success; 1 endpoint unreachable, model missing, or request/write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ModelId,
    [Parameter(Mandatory=$true)][string]$PromptPath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [Parameter(Mandatory=$false)][int]$MaxTokens = 4096,
    [Parameter(Mandatory=$false)][double]$Temperature = 1.0
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
    ConvertTo-Json -InputObject $Data -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-HttpErrorMessage {
    param($ErrorRecord)
    $detail = [string]$ErrorRecord.ErrorDetails.Message
    if (-not [string]::IsNullOrWhiteSpace($detail)) { return $detail }
    if ($ErrorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.Exception.Message)) { return $ErrorRecord.Exception.Message }
    return [string]$ErrorRecord
}

function ConvertTo-TokenCount {
    param($Value)
    if ($null -eq $Value) { return 0 }
    try { return [int]$Value } catch { return 0 }
}

$endpoint = Get-OllamaEndpoint

try {
    if (-not (Test-Path -LiteralPath $PromptPath)) { throw "PromptPath not found: $PromptPath" }

    $prompt = Get-Content -LiteralPath $PromptPath -Raw -Encoding UTF8
    $body = [ordered]@{
        model = $ModelId
        messages = @(
            [ordered]@{
                role = 'user'
                content = $prompt
            }
        )
        stream = $false
        options = [ordered]@{
            num_predict = $MaxTokens
            temperature = $Temperature
        }
    }

    $response = Invoke-RestMethod -Uri "$endpoint/api/chat" -Method Post -Body (ConvertTo-Json -InputObject $body -Depth 20) -ContentType 'application/json' -TimeoutSec 600

    $promptTokens = ConvertTo-TokenCount -Value $response.prompt_eval_count
    $completionTokens = ConvertTo-TokenCount -Value $response.eval_count
    $completion = ''
    if ($response.message -and $response.message.PSObject.Properties['content']) { $completion = [string]$response.message.content }

    $result = [ordered]@{
        status = 'success'
        adapter = 'ollama'
        model_id = $ModelId
        completion = $completion
        usage = [ordered]@{
            prompt_tokens = $promptTokens
            completion_tokens = $completionTokens
            total_tokens = ($promptTokens + $completionTokens)
        }
        cost_estimate = 0.0
        top_provider = 'ollama-local'
    }

    Write-JsonOutput -Data $result -Path $OutPath
    exit 0
} catch {
    $message = Get-HttpErrorMessage -ErrorRecord $_
    if ($message -match '(?i)model.*(not found|not.*pulled|pull)|pull.*model|404') {
        Write-Error -ErrorAction Continue "Ollama model '$ModelId' is not pulled or is unavailable at '$endpoint'. Run: ollama pull $ModelId. Details: $message"
    } elseif ($message -match '(?i)connection refused|actively refused|no connection|unable to connect|name resolution|timed out|refused') {
        Write-Error -ErrorAction Continue "Ollama endpoint '$endpoint' is unreachable. Start Ollama with 'ollama serve' or set OLLAMA_ENDPOINT. Details: $message"
    } else {
        Write-Error -ErrorAction Continue "Ollama dispatch failed for model '$ModelId' at '$endpoint'. Confirm Ollama is running and the model is pulled. Details: $message"
    }
    exit 1
}
