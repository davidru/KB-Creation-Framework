# Title: inspect-runner.ps1 — PowerShell wrapper around evaluator/inspect-runner.py (v3.1.15)
# Purpose: Phase 7.0 test-set evaluation
# Usage:
#   pwsh inspect-runner.ps1 -TestSet .\audit\test-set.yaml -KBRoot . [-Mode auto|llm|fallback]
# Exit codes: 0 threshold met, 1 threshold NOT met, 2 test-set missing/invalid, 3 KB empty, 4 LLM unavailable

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$TestSet,
    [Parameter(Mandatory=$true)][string]$KBRoot,
    [ValidateSet('auto','llm','fallback')][string]$Mode = 'auto',
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$python = $null
foreach ($c in @('python','python3','py')) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { $python = $cmd.Source; break } }
if (-not $python) {
    Write-Output (@{ status='error'; adapter='evaluator'; error_type='python_missing'; remediation='Install Python 3.12+.' } | ConvertTo-Json)
    exit 4
}

$resolvedTs = if ([System.IO.Path]::IsPathRooted($TestSet)) { $TestSet } else { Join-Path (Get-Location).Path $TestSet }
$resolvedKB = if ([System.IO.Path]::IsPathRooted($KBRoot)) { $KBRoot } else { Join-Path (Get-Location).Path $KBRoot }

$pyArgs = @((Join-Path $ScriptDir 'inspect-runner.py'), '--test-set', $resolvedTs, '--kb-root', $resolvedKB, '--mode', $Mode)
$output = & $python @pyArgs 2>&1
$exit = $LASTEXITCODE
$joined = ($output | ForEach-Object { [string]$_ }) -join "`n"
$parsed = $null; try { $parsed = $joined | ConvertFrom-Json } catch { }

if ($Json -or -not $parsed) { Write-Output $joined }
else {
    if ($parsed.status -eq 'ok') {
        Write-Host ("Mode:         {0}" -f $parsed.mode)
        Write-Host ("Questions:    {0} ({1} passed, {2} failed, {3} errored, {4} N/A)" -f $parsed.total, $parsed.passed, $parsed.failed, $parsed.errored, $parsed.na)
        $color = if ($parsed.threshold_met) { 'Green' } else { 'Red' }
        Write-Host ("Passage rate: {0:P0} (threshold {1:P0})" -f $parsed.passage_rate, $parsed.threshold_passage_rate) -ForegroundColor $color
        Write-Host ("Threshold:    {0}" -f $(if ($parsed.threshold_met) { 'MET' } else { 'NOT MET' })) -ForegroundColor $color
        if ($parsed.blocker_failed) { Write-Host "⚠️ BLOCKER FAILURES present — composite cannot PASS" -ForegroundColor Red }
        Write-Host ("Report (md):  {0}" -f $parsed.results_md)
        Write-Host ("Report (json):{0}" -f $parsed.results_json)
    } else {
        Write-Host ("Error type:  {0}" -f $parsed.error_type) -ForegroundColor Red
        Write-Host ("Message:     {0}" -f $parsed.error_message) -ForegroundColor Red
        if ($parsed.remediation) { Write-Host ("Remediation: {0}" -f $parsed.remediation) -ForegroundColor Yellow }
    }
}
exit $exit
