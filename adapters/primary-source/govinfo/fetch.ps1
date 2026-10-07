# Title: fetch.ps1 — PowerShell wrapper around govinfo/fetch.py (v3.1.13)
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('FR','USCODE','PLAW','BILLS','STATUTE','CFR')][string]$Collection,
    [string]$PackageId = '',
    [int]$Year = 0,
    [string]$Title = '',
    [string]$Section = '',
    [int]$Congress = 0,
    [int]$LawNumber = 0,
    [Parameter(Mandatory=$true)][string]$CachePath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$python = $null
foreach ($c in @('python','python3','py')) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { $python = $cmd.Source; break } }
if (-not $python) {
    Write-Output (@{ status='error'; adapter='govinfo'; error_type='python_missing'; error_message='No python found.'; remediation='Install Python 3.12+.' } | ConvertTo-Json)
    exit 4
}
$resolvedCache = if ([System.IO.Path]::IsPathRooted($CachePath)) { $CachePath } else { Join-Path (Get-Location).Path $CachePath }
$null = New-Item -ItemType Directory -Path $resolvedCache -Force -ErrorAction SilentlyContinue
$pyArgs = @((Join-Path $ScriptDir 'fetch.py'), '--collection', $Collection)
if ($PackageId) { $pyArgs += @('--package-id', $PackageId) }
if ($Year -gt 0) { $pyArgs += @('--year', $Year) }
if ($Title) { $pyArgs += @('--title', $Title) }
if ($Section) { $pyArgs += @('--section', $Section) }
if ($Congress -gt 0) { $pyArgs += @('--congress', $Congress) }
if ($LawNumber -gt 0) { $pyArgs += @('--law-number', $LawNumber) }
$pyArgs += @('--cache', $resolvedCache)
$output = & $python @pyArgs 2>&1
$exit = $LASTEXITCODE
$joined = ($output | ForEach-Object { [string]$_ }) -join "`n"
$parsed = $null; try { $parsed = $joined | ConvertFrom-Json } catch { }
if ($Json -or -not $parsed) { Write-Output $joined }
else {
    Write-Host "Adapter:     $($parsed.adapter)"; Write-Host "Status:      $($parsed.status)"
    if ($parsed.status -eq 'success') {
        Write-Host "Package:     $($parsed.package_id) ($($parsed.collection))"; Write-Host "Diff:        $($parsed.diff_status)"
        Write-Host "Size:        $($parsed.size) bytes (sha256 $($parsed.sha256.Substring(0,12)))"
        Write-Host "Citation:    $($parsed.citation)"
    } else {
        Write-Host "Error type:  $($parsed.error_type)" -ForegroundColor Red
        Write-Host "Message:     $($parsed.error_message)" -ForegroundColor Red
        Write-Host "Remediation: $($parsed.remediation)" -ForegroundColor Yellow
    }
}
exit $exit
