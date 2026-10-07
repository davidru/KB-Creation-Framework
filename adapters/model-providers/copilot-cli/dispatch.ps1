# Title: dispatch.ps1 — Copilot CLI provider adapter dispatch envelope.
# Purpose: Validate Copilot CLI model IDs and emit host task-tool dispatch instructions.
# Inputs: -ModelId, -PromptPath, and -OutPath.
# Outputs: Pretty JSON dispatch envelope at -OutPath and stdout.
# Exit codes: 0 ready; 1 validation or file-read failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ModelId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$PromptPath,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutPath
)

$ErrorActionPreference = 'Stop'

$KnownModelIds = @(
    'claude-sonnet-4.6',
    'claude-sonnet-4.5',
    'claude-haiku-4.5',
    'claude-opus-4.8',
    'claude-opus-4.7',
    'claude-opus-4.7-1m-internal',
    'claude-opus-4.7-high',
    'claude-opus-4.7-xhigh',
    'claude-opus-4.6',
    'claude-opus-4.6-1m',
    'claude-opus-4.5',
    'gpt-5.5',
    'gpt-5.4',
    'gpt-5.3-codex',
    'gpt-5.4-mini',
    'gpt-5-mini',
    'gemini-3.1-pro-preview',
    'gemini-3.5-flash',
    'mai-code-1-flash-internal'
)

function New-ErrorEnvelope {
    param(
        [Parameter(Mandatory=$true)][string]$Code,
        [Parameter(Mandatory=$true)][string]$Message
    )

    return [ordered]@{
        status = 'error'
        adapter = 'copilot-cli'
        model_id = $ModelId
        error = [ordered]@{
            code = $Code
            message = $Message
        }
        known_model_ids = $KnownModelIds
    }
}

function Write-JsonOutput {
    param(
        [Parameter(Mandatory=$true)]$Data,
        [Parameter(Mandatory=$true)][string]$Path
    )

    $json = $Data | ConvertTo-Json -Depth 20
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json | Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Output $json
}

try {
    if ($KnownModelIds -notcontains $ModelId) {
        $errorEnvelope = New-ErrorEnvelope -Code 'unknown_model_id' -Message "ModelId '$ModelId' is not in the hardcoded Copilot CLI model list."
        Write-JsonOutput -Data $errorEnvelope -Path $OutPath
        exit 1
    }

    if (-not (Test-Path -LiteralPath $PromptPath -PathType Leaf)) {
        $errorEnvelope = New-ErrorEnvelope -Code 'prompt_not_found' -Message "PromptPath not found: $PromptPath"
        Write-JsonOutput -Data $errorEnvelope -Path $OutPath
        exit 1
    }

    $prompt = Get-Content -LiteralPath $PromptPath -Raw -Encoding UTF8
    $envelope = [ordered]@{
        status = 'ready'
        adapter = 'copilot-cli'
        model_id = $ModelId
        host_invocation = [ordered]@{
            tool = 'task'
            parameters = [ordered]@{
                model = $ModelId
                prompt = $prompt
                mode = 'background'
            }
        }
    }

    Write-JsonOutput -Data $envelope -Path $OutPath
    exit 0
} catch {
    $errorEnvelope = New-ErrorEnvelope -Code 'dispatch_envelope_failed' -Message $_.Exception.Message
    Write-JsonOutput -Data $errorEnvelope -Path $OutPath
    exit 1
}
