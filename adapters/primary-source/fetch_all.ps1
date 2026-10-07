# Title: fetch_all.ps1 — PowerShell wrapper around primary-source/fetch_all.py
# Purpose: Multi-source fetch + drift detection orchestrator (v3.1.13)
# Usage:
#   pwsh fetch_all.ps1 -Registry .\sources\source-registry.yaml -CachePath .\external\primary-sources\cache -KBRoot . [-DriftReportOnly]
# Exit codes: 0 success no foundational drift, 1 foundational source drifted (review required), 2 registry invalid, 3 adapter error, 4 python missing

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Registry,
    [Parameter(Mandatory=$true)][string]$CachePath,
    [Parameter(Mandatory=$true)][string]$KBRoot,
    [switch]$DriftReportOnly,
    [switch]$NoReport,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

$python = $null
foreach ($c in @('python','python3','py')) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { $python = $cmd.Source; break } }
if (-not $python) {
    Write-Output (@{ status='error'; error_type='python_missing'; remediation='Install Python 3.12+.' } | ConvertTo-Json)
    exit 4
}

$resolvedRegistry = if ([System.IO.Path]::IsPathRooted($Registry)) { $Registry } else { Join-Path (Get-Location).Path $Registry }
$resolvedCache = if ([System.IO.Path]::IsPathRooted($CachePath)) { $CachePath } else { Join-Path (Get-Location).Path $CachePath }
$resolvedKB = if ([System.IO.Path]::IsPathRooted($KBRoot)) { $KBRoot } else { Join-Path (Get-Location).Path $KBRoot }

$pyArgs = @((Join-Path $ScriptDir 'fetch_all.py'), '--registry', $resolvedRegistry, '--cache', $resolvedCache, '--kb-root', $resolvedKB)
if ($DriftReportOnly) { $pyArgs += '--drift-report-only' }
if ($NoReport) { $pyArgs += '--no-report' }

$output = & $python @pyArgs 2>&1
$exit = $LASTEXITCODE
$joined = ($output | ForEach-Object { [string]$_ }) -join "`n"
$parsed = $null; try { $parsed = $joined | ConvertFrom-Json } catch { }

if ($Json -or -not $parsed) { Write-Output $joined }
else {
    if ($parsed.status -eq 'success') {
        $c = $parsed.counts
        Write-Host "Fetched $($c.total) sources: $($c.new) new, $($c.unchanged) unchanged, $($c.changed) changed, $($c.errored) errored"
        if ($c.drift_blocking -gt 0) {
            Write-Host ("BLOCKING: $($c.drift_blocking) foundational source(s) drifted. See drift report:") -ForegroundColor Red
            Write-Host ("  $($parsed.drift_report)") -ForegroundColor Yellow
        } else {
            Write-Host ("Drift report: $($parsed.drift_report)") -ForegroundColor Green
        }
    } else {
        Write-Host "Error: $($parsed.error_type) — $($parsed.error_message)" -ForegroundColor Red
        if ($parsed.remediation) { Write-Host "Remediation: $($parsed.remediation)" -ForegroundColor Yellow }
    }
}
exit $exit
