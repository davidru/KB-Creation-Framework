# Title: llamaindex-citation.ps1 — PowerShell wrapper around citation-engine/llamaindex-citation.py (v3.1.14)
# Purpose: Phase 5.6 citation-engine fact-check
# Usage:
#   pwsh llamaindex-citation.ps1 -DraftsDir .\sources\builder-drafts -SourcesDir .\external\primary-sources\cache -KBRoot .
# Exit codes: 0 success, 1 partial (some cites errored), 2 nothing to verify, 3 no indexed sources, 4 LLM unavailable, 5 missing API key

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$DraftsDir,
    [Parameter(Mandatory=$true)][string]$SourcesDir,
    [Parameter(Mandatory=$true)][string]$KBRoot,
    [ValidateSet('auto','llm','fallback')][string]$Mode = 'auto',
    [ValidateSet('openrouter','openai','anthropic')][string]$LlmProvider = 'openrouter',
    [string]$LlmModel = 'openai/gpt-4o-mini',
    [string]$EmbeddingModel = 'text-embedding-3-small',
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$python = $null
foreach ($c in @('python','python3','py')) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { $python = $cmd.Source; break } }
if (-not $python) {
    Write-Output (@{ status='error'; adapter='citation-engine'; error_type='python_missing'; remediation='Install Python 3.12+.' } | ConvertTo-Json)
    exit 4
}

$resolvedDrafts = if ([System.IO.Path]::IsPathRooted($DraftsDir)) { $DraftsDir } else { Join-Path (Get-Location).Path $DraftsDir }
$resolvedSources = if ([System.IO.Path]::IsPathRooted($SourcesDir)) { $SourcesDir } else { Join-Path (Get-Location).Path $SourcesDir }
$resolvedKB = if ([System.IO.Path]::IsPathRooted($KBRoot)) { $KBRoot } else { Join-Path (Get-Location).Path $KBRoot }

$pyArgs = @(
    (Join-Path $ScriptDir 'llamaindex-citation.py'),
    '--drafts-dir', $resolvedDrafts,
    '--sources-dir', $resolvedSources,
    '--kb-root', $resolvedKB,
    '--mode', $Mode,
    '--llm-provider', $LlmProvider,
    '--llm-model', $LlmModel,
    '--embedding-model', $EmbeddingModel
)
$output = & $python @pyArgs 2>&1
$exit = $LASTEXITCODE
$joined = ($output | ForEach-Object { [string]$_ }) -join "`n"
$parsed = $null; try { $parsed = $joined | ConvertFrom-Json } catch { }

if ($Json -or -not $parsed) { Write-Output $joined }
else {
    if ($parsed.status -eq 'ok') {
        Write-Host ("Mode:           {0}" -f $parsed.mode)
        Write-Host ("Cites checked:  {0}" -f $parsed.total)
        if ($parsed.counts) {
            foreach ($k in $parsed.counts.PSObject.Properties.Name | Where-Object { $_ -ne 'total' }) {
                $v = $parsed.counts.$k
                $color = switch -Wildcard ($k) { 'VERIFIED*' {'Green'} 'NOT_FOUND' {'Red'} 'WRONG_TEXT' {'Red'} 'ERRORED' {'Red'} default {'Yellow'} }
                Write-Host ("  {0}: {1}" -f $k, $v) -ForegroundColor $color
            }
        }
        if ($parsed.factcheck_report_md) { Write-Host ("Report (md):    {0}" -f $parsed.factcheck_report_md) }
        if ($parsed.factcheck_report_json) { Write-Host ("Report (json):  {0}" -f $parsed.factcheck_report_json) }
    } else {
        Write-Host ("Error type:  {0}" -f $parsed.error_type) -ForegroundColor Red
        Write-Host ("Message:     {0}" -f $parsed.error_message) -ForegroundColor Red
        if ($parsed.remediation) { Write-Host ("Remediation: {0}" -f $parsed.remediation) -ForegroundColor Yellow }
    }
}
exit $exit
