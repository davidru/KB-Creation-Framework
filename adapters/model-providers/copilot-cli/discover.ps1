# Title: discover.ps1 — Copilot CLI model-list adapter.
# Purpose: Emit the hardcoded Copilot CLI task-tool model catalog.
# Inputs: Optional -OutPath for the JSON array artifact.
# Outputs: Pretty JSON model array at -OutPath and stdout.
# Exit codes: 0 success; 1 write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

$commonNotes = 'Hardcoded from the Copilot CLI task model parameter list; availability depends on the active Copilot CLI installation and account.'
$models = @(
    [ordered]@{ model_id = 'claude-sonnet-4.6'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-sonnet-4.5'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-haiku-4.5'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'low-latency'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.8'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'premium-lead'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.7'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'premium-lead'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.7-1m-internal'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'long-context', 'internal'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.7-high'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'high-reasoning'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.7-xhigh'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'extra-high-reasoning'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.6'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'premium-lead'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.6-1m'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'long-context'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'claude-opus-4.5'; family_hint = 'anthropic'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'premium-lead'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gpt-5.5'; family_hint = 'openai'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'fact-check'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gpt-5.4'; family_hint = 'openai'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gpt-5.3-codex'; family_hint = 'openai'; context_window_estimate = $null; capabilities = @('text', 'tools', 'coding', 'reasoning'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gpt-5.4-mini'; family_hint = 'openai'; context_window_estimate = $null; capabilities = @('text', 'tools', 'low-latency'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gpt-5-mini'; family_hint = 'openai'; context_window_estimate = $null; capabilities = @('text', 'tools', 'low-latency'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gemini-3.1-pro-preview'; family_hint = 'google'; context_window_estimate = $null; capabilities = @('text', 'tools', 'reasoning', 'audit'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'gemini-3.5-flash'; family_hint = 'google'; context_window_estimate = $null; capabilities = @('text', 'tools', 'low-latency'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes },
    [ordered]@{ model_id = 'mai-code-1-flash-internal'; family_hint = 'internal-microsoft'; context_window_estimate = $null; capabilities = @('text', 'tools', 'coding', 'low-latency', 'internal'); created = $null; pricing = $null; top_provider = 'copilot-cli'; notes = $commonNotes }
)

function Write-JsonOutput {
    param(
        [Parameter(Mandatory=$true)]$Data,
        [Parameter(Mandatory=$false)][string]$Path = ''
    )

    $json = $Data | ConvertTo-Json -Depth 20
    if ($Path) {
        $parent = Split-Path -Parent $Path
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        $json | Set-Content -LiteralPath $Path -Encoding UTF8
    }
    Write-Output $json
}

try {
    Write-JsonOutput -Data $models -Path $OutPath
    exit 0
} catch {
    $errorEnvelope = [ordered]@{
        status = 'error'
        adapter = 'copilot-cli'
        error = [ordered]@{
            code = 'discover_failed'
            message = $_.Exception.Message
        }
    }
    Write-JsonOutput -Data $errorEnvelope
    exit 1
}
