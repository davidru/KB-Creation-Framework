# Title: fetch.ps1 — PowerShell wrapper around ecfr/fetch.py
# Purpose: Frame-friendly PowerShell entry point; normalizes Windows paths, captures Python JSON output, returns structured pscustomobject.
# Version: v3.1.13
# Usage: pwsh fetch.ps1 -CiteString "17 CFR 240.10b-5" -CachePath ".\external\primary-sources\cache" [-AsOf 2026-06-08]
# Exit codes: 0 success, 1 fetch error, 2 cite parse error, 3 cache write error, 4 Python missing.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$CiteString,
    [Parameter(Mandatory=$true)][string]$CachePath,
    [string]$AsOf = '',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

# Locate Python
$python = $null
foreach ($candidate in @('python','python3','py')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source; break }
}
if (-not $python) {
    $err = @{
        status = 'error'
        adapter = 'ecfr'
        error_type = 'python_missing'
        error_message = 'No python/python3/py interpreter found on PATH.'
        remediation = 'Install Python 3.12+ via ~/.copilot/bootstrap.ps1 or `winget install Python.Python.3.12`.'
    }
    Write-Output ($err | ConvertTo-Json)
    exit 4
}

# Resolve cache path to absolute
$resolvedCache = if ([System.IO.Path]::IsPathRooted($CachePath)) { $CachePath } else { Join-Path (Get-Location).Path $CachePath }
$null = New-Item -ItemType Directory -Path $resolvedCache -Force -ErrorAction SilentlyContinue

$pyArgs = @((Join-Path $ScriptDir 'fetch.py'), '--cite', $CiteString, '--cache', $resolvedCache)
if ($AsOf) { $pyArgs += @('--as-of', $AsOf) }

$output = & $python @pyArgs 2>&1
$exit = $LASTEXITCODE
$joined = ($output | ForEach-Object { [string]$_ }) -join "`n"

# Parse JSON from Python
$parsed = $null
try { $parsed = $joined | ConvertFrom-Json } catch { $parsed = $null }

if ($Json -or -not $parsed) {
    Write-Output $joined
} else {
    Write-Host ("Adapter:     {0}" -f $parsed.adapter)
    Write-Host ("Status:      {0}" -f $parsed.status)
    if ($parsed.status -eq 'success') {
        Write-Host ("Cite:        {0}" -f $parsed.cite_string)
        Write-Host ("As of:       {0}" -f $parsed.as_of)
        Write-Host ("Diff:        {0}" -f $parsed.diff_status)
        Write-Host ("Size:        {0} bytes (sha256 {1})" -f $parsed.size, $parsed.sha256.Substring(0,12))
        Write-Host ("Cache path:  {0}" -f $parsed.cache_path)
        Write-Host ("Source URL:  {0}" -f $parsed.source_url)
    } else {
        Write-Host ("Error type:  {0}" -f $parsed.error_type) -ForegroundColor Red
        Write-Host ("Message:     {0}" -f $parsed.error_message) -ForegroundColor Red
        Write-Host ("Remediation: {0}" -f $parsed.remediation) -ForegroundColor Yellow
    }
}

exit $exit
