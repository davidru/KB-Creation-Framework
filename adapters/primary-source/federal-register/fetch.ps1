# Title: fetch.ps1 — PowerShell wrapper around federal-register/fetch.py (v3.1.13)
[CmdletBinding(DefaultParameterSetName='Cite')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='Cite')][string]$Cite,
    [Parameter(Mandatory=$true,ParameterSetName='DocumentNumber')][string]$DocumentNumber,
    [Parameter(Mandatory=$true,ParameterSetName='DocketId')][string]$DocketId,
    [Parameter(Mandatory=$true)][string]$CachePath,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$python = $null
foreach ($c in @('python','python3','py')) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { $python = $cmd.Source; break } }
if (-not $python) {
    Write-Output (@{ status='error'; adapter='federal-register'; error_type='python_missing'; error_message='No python found on PATH.'; remediation='Install Python 3.12+.' } | ConvertTo-Json)
    exit 4
}
$resolvedCache = if ([System.IO.Path]::IsPathRooted($CachePath)) { $CachePath } else { Join-Path (Get-Location).Path $CachePath }
$null = New-Item -ItemType Directory -Path $resolvedCache -Force -ErrorAction SilentlyContinue
$pyArgs = @((Join-Path $ScriptDir 'fetch.py'))
switch ($PSCmdlet.ParameterSetName) {
    'Cite' { $pyArgs += @('--cite', $Cite) }
    'DocumentNumber' { $pyArgs += @('--document-number', $DocumentNumber) }
    'DocketId' { $pyArgs += @('--docket-id', $DocketId) }
}
$pyArgs += @('--cache', $resolvedCache)
$output = & $python @pyArgs 2>&1
$exit = $LASTEXITCODE
$joined = ($output | ForEach-Object { [string]$_ }) -join "`n"
$parsed = $null; try { $parsed = $joined | ConvertFrom-Json } catch { }
if ($Json -or -not $parsed) { Write-Output $joined }
else {
    Write-Host "Adapter:     $($parsed.adapter)"; Write-Host "Status:      $($parsed.status)"
    if ($parsed.status -eq 'success') {
        Write-Host "Identifier:  $($parsed.identifier)"; Write-Host "Diff:        $($parsed.diff_status)"
        Write-Host "Size:        $($parsed.size) bytes (sha256 $($parsed.sha256.Substring(0,12)))"
        Write-Host "Cache path:  $($parsed.cache_path)"; Write-Host "Citation:    $($parsed.citation)"
    } else {
        Write-Host "Error type:  $($parsed.error_type)" -ForegroundColor Red
        Write-Host "Message:     $($parsed.error_message)" -ForegroundColor Red
        Write-Host "Remediation: $($parsed.remediation)" -ForegroundColor Yellow
    }
}
exit $exit
