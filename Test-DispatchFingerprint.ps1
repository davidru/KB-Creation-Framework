<#
.SYNOPSIS
    Test-DispatchFingerprint.ps1 — v3.1.10 silent-fallback detector.

.DESCRIPTION
    Verifies that a sub-agent response was actually produced by the intended
    OpenCode sub-agent, not by the parent (Lead) model after a silent fallback.

    The mechanism: Render-OpenCodeAgents.ps1 (v3.1.10+) embeds a deterministic
    DISPATCH-FINGERPRINT in each sub-agent's prompt. When the orchestrator
    prepends the literal token "ECHO-FINGERPRINT" to its Task dispatch, a
    correctly-routed sub-agent reads its own prompt and echoes the fingerprint
    on the first non-empty line of its response. A parent-model silent-fallback
    cannot see the sub-agent's prompt and therefore cannot produce the
    fingerprint — exposing the silent fallback at dispatch time, not at Phase 9
    scorecard generation.

    The script reads the expected fingerprint from the agent's `description`
    field in opencode.json (Render-OpenCodeAgents v3.1.10+ writes it as
    `[FP: DISPATCH-FINGERPRINT::<agent>::<hex>]`) and compares against the
    fingerprint extracted from the response text.

.PARAMETER OpenCodeJsonPath
    Path to opencode.json. Required.

.PARAMETER AgentName
    The sub-agent name dispatched (the value passed as subagent_type to the
    Task tool, e.g. "builder-a", "factcheck-pool-5a-5b-5c-handle-1"). Required.

.PARAMETER ResponseText
    The response text from the sub-agent. Required. Pass the full response or
    at least the first 500 characters — the script scans for the fingerprint
    pattern, not by position.

.PARAMETER Quiet
    Suppress informational output; emit only the PASS/FAIL line + exit code.

.PARAMETER Json
    Emit the result as a single JSON object instead of text. Includes:
    {status, agent_name, expected_fingerprint, observed_fingerprint, opencode_json_path,
     remediation, dispatch_status_recommendation}.

.EXITCODES
    0 = match (dispatched-as-intended).
    1 = mismatch (dispatched-with-substitution — silent fallback detected).
    2 = expected fingerprint not found in opencode.json (agent not rendered by
        v3.1.10+ renderer, or agent_name is wrong).
    3 = opencode.json unreadable or missing.

.EXAMPLE
    pwsh ./Test-DispatchFingerprint.ps1 -OpenCodeJsonPath .\opencode.json `
         -AgentName 'builder-a' -ResponseText $response.completion

.RELATED
    Render-OpenCodeAgents.ps1 (v3.1.10+) — embeds the fingerprint into each agent's prompt and description.
    prompts/01-orchestrator.md — MODEL ASSIGNMENT PLUMBING + DISPATCH-FAILURE CONTRACT.
    Generate-QualityScorecard.ps1 — v3.1.9 Rule 19 actuals evaluator.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OpenCodeJsonPath,
    [Parameter(Mandatory=$true)][string]$AgentName,
    [Parameter(Mandatory=$true)][string]$ResponseText,
    [switch]$Quiet,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param([hashtable]$Result)
    if ($Json) {
        ($Result | ConvertTo-Json -Depth 5)
        return
    }
    if (-not $Quiet) {
        Write-Host "Agent:                $($Result.agent_name)"
        Write-Host "OpenCode JSON:        $($Result.opencode_json_path)"
        Write-Host "Expected fingerprint: $($Result.expected_fingerprint)"
        Write-Host "Observed fingerprint: $($Result.observed_fingerprint)"
        Write-Host "Recommended log:      dispatch_status: $($Result.dispatch_status_recommendation)"
        if ($Result.remediation) { Write-Host "Remediation:          $($Result.remediation)" }
    }
    if ($Result.status -eq 'match') {
        Write-Host "PASS: dispatch fingerprint matched. Routing OK." -ForegroundColor Green
    } else {
        Write-Host "FAIL: dispatch fingerprint $($Result.status). Silent fallback to parent model is likely." -ForegroundColor Red
    }
}

try {
    if (-not (Test-Path -LiteralPath $OpenCodeJsonPath -PathType Leaf)) {
        Write-Result @{
            status                          = 'opencode_json_missing'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $null
            observed_fingerprint            = $null
            dispatch_status_recommendation  = 'failed-then-acknowledged-opt-out'
            remediation                     = "opencode.json not found at '$OpenCodeJsonPath'. Run Render-OpenCodeAgents.ps1 first."
        }
        exit 3
    }

    $config = $null
    try { $config = Get-Content -LiteralPath $OpenCodeJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop } catch {
        Write-Result @{
            status                          = 'opencode_json_unreadable'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $null
            observed_fingerprint            = $null
            dispatch_status_recommendation  = 'failed-then-acknowledged-opt-out'
            remediation                     = "opencode.json is not valid JSON: $($_.Exception.Message)"
        }
        exit 3
    }

    $agentBlock = $null
    if ($config.agent) {
        $agentBlock = $config.agent.PSObject.Properties | Where-Object { $_.Name -eq $AgentName } | Select-Object -First 1
    }
    if (-not $agentBlock) {
        $valid = if ($config.agent) { @($config.agent.PSObject.Properties.Name) -join ', ' } else { '(no agent: block in opencode.json)' }
        Write-Result @{
            status                          = 'agent_not_in_opencode_json'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $null
            observed_fingerprint            = $null
            dispatch_status_recommendation  = 'failed-then-acknowledged-opt-out'
            remediation                     = "Agent '$AgentName' is not in opencode.json's agent: block. Valid agent names: $valid. Re-render with Render-OpenCodeAgents.ps1 or check the subagent_type spelling."
        }
        exit 2
    }

    $description = [string]$agentBlock.Value.description
    $expectedMatch = [regex]::Match($description, 'DISPATCH-FINGERPRINT::([^\s\]]+?)::([0-9a-f]+)')
    if (-not $expectedMatch.Success) {
        Write-Result @{
            status                          = 'expected_fingerprint_missing'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $null
            observed_fingerprint            = $null
            dispatch_status_recommendation  = 'failed-then-acknowledged-opt-out'
            remediation                     = "Agent '$AgentName' has no DISPATCH-FINGERPRINT in its description. opencode.json was probably rendered by a pre-v3.1.10 Render-OpenCodeAgents.ps1. Re-render to embed fingerprints."
        }
        exit 2
    }
    $expectedFingerprint = $expectedMatch.Value

    $observedMatch = [regex]::Match($ResponseText, 'DISPATCH-FINGERPRINT::([^\s\]]+?)::([0-9a-f]+)')
    $observedFingerprint = if ($observedMatch.Success) { $observedMatch.Value } else { $null }

    if (-not $observedFingerprint) {
        Write-Result @{
            status                          = 'no_fingerprint_in_response'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $expectedFingerprint
            observed_fingerprint            = $null
            dispatch_status_recommendation  = 'dispatched-with-substitution'
            remediation                     = "Response from dispatch to '$AgentName' contained no DISPATCH-FINGERPRINT. Either (a) the orchestrator failed to prepend 'ECHO-FINGERPRINT' to its task prompt, or (b) silent fallback to parent model occurred and the parent doesn't have the subagent's prompt. Check the orchestrator's dispatch prompt; if 'ECHO-FINGERPRINT' was prepended, this is silent-fallback. Per DISPATCH-FAILURE CONTRACT: stop the affected phase and surface to operator."
        }
        exit 1
    }

    if ($observedFingerprint -eq $expectedFingerprint) {
        Write-Result @{
            status                          = 'match'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $expectedFingerprint
            observed_fingerprint            = $observedFingerprint
            dispatch_status_recommendation  = 'dispatched-as-intended'
            remediation                     = $null
        }
        exit 0
    } else {
        Write-Result @{
            status                          = 'fingerprint_mismatch'
            agent_name                      = $AgentName
            opencode_json_path              = $OpenCodeJsonPath
            expected_fingerprint            = $expectedFingerprint
            observed_fingerprint            = $observedFingerprint
            dispatch_status_recommendation  = 'dispatched-with-substitution'
            remediation                     = "Response contained a DISPATCH-FINGERPRINT, but it does not match the expected one for agent '$AgentName'. The dispatch may have been routed to a different (wrong) subagent. Per DISPATCH-FAILURE CONTRACT: stop the affected phase and surface to operator."
        }
        exit 1
    }
} catch {
    Write-Result @{
        status                          = 'script_error'
        agent_name                      = $AgentName
        opencode_json_path              = $OpenCodeJsonPath
        expected_fingerprint            = $null
        observed_fingerprint            = $null
        dispatch_status_recommendation  = 'failed-then-acknowledged-opt-out'
        remediation                     = "Test-DispatchFingerprint.ps1 errored: $($_.Exception.Message)"
    }
    exit 3
}
