<#
.SYNOPSIS
    Extract-AuthorityView.ps1 — v3 authority-view extractor with inline-tag precheck.

.DESCRIPTION
    Generates the authority/ folder from the full/ folder by stripping every
    paragraph tagged with <!-- [GUIDANCE] --> or <!-- [INTERPRETATION] -->. v3
    adds a pre-extraction validator that rejects inline-position register tags:
    if text appears before a GUIDANCE or INTERPRETATION tag on the same line,
    extraction stops and the operator must fix the tag placement first.

.PARAMETER KBRoot
    KB root directory. Reads $KBRoot\full\*.md and writes $KBRoot\authority\*.md.

.EXITCODES
    0 = PASS / extraction complete.
    1 = full/ missing or inline-position register tag rejected.
    2 = reserved for future hard verification gate failures.

.RELATED
    KB Creation - Modular v3\07-audit-system.md — three-tier output and scorecard inputs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$KBRoot
)

$ErrorActionPreference = 'Stop'

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

function Test-InlineRegisterTags {
    param([System.IO.FileInfo[]]$Files)
    $findings = New-Object System.Collections.Generic.List[psobject]
    foreach ($file in $Files) {
        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->' -and $line -notmatch '^\s*<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->') {
                $findings.Add([pscustomobject]@{ File=$file.Name; Line=$i + 1; Text=$line.Trim() }) | Out-Null
            }
        }
    }
    return @($findings)
}

$fullDir = Join-Path $KBRoot 'full'
$authDir = Join-Path $KBRoot 'authority'
$sourcesDir = Join-Path $KBRoot 'sources'
$reportPath = Join-Path $sourcesDir 'authority_view_extraction.md'

if (-not (Test-Path -LiteralPath $sourcesDir)) { New-Item -ItemType Directory -Path $sourcesDir -Force | Out-Null }

if (-not (Test-Path -LiteralPath $fullDir)) {
    @("# Authority View Extraction Report", "", "## VERDICT: BLOCK", "", "full/ directory not found: ``$fullDir``") | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "Authority extraction blocked: full/ not found. Report at $reportPath"
    exit 1
}

$files = @(Get-ChildItem -LiteralPath $fullDir -Filter '*.md' -File)
$inlineFindings = @(Test-InlineRegisterTags -Files $files)
if ($inlineFindings.Count -gt 0) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Authority View Extraction Report') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## VERDICT: BLOCK') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('Inline-position register tags were found. Register tags must appear at the beginning of the tagged paragraph line before extraction.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| File | Line | Text |') | Out-Null
    $lines.Add('|---|---:|---|') | Out-Null
    foreach ($f in $inlineFindings) { $lines.Add("| $($f.File) | $($f.Line) | $(Escape-Md $f.Text) |") | Out-Null }
    $lines -join "`n" | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "Authority extraction blocked: $($inlineFindings.Count) inline register tag(s). Report at $reportPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $authDir)) { New-Item -ItemType Directory -Path $authDir -Force | Out-Null }

$stats = New-Object System.Collections.Generic.List[psobject]
foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
    $outputLines = New-Object System.Collections.Generic.List[string]
    $stripped = 0
    $inStrippedBlock = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->') {
            $stripped++
            $inStrippedBlock = $true
            continue
        }
        if ($inStrippedBlock) {
            if ($line -match '^\s*$' -or $line -match '^#{1,6}\s' -or $line -match '^---\s*$') {
                $inStrippedBlock = $false
                $outputLines.Add($line) | Out-Null
            }
            continue
        }
        $outputLines.Add($line) | Out-Null
    }

    $finalLines = New-Object System.Collections.Generic.List[string]
    $blankCount = 0
    foreach ($line in $outputLines) {
        if ($line.Trim() -eq '') {
            $blankCount++
            if ($blankCount -le 2) { $finalLines.Add($line) | Out-Null }
        } else {
            $blankCount = 0
            $finalLines.Add($line) | Out-Null
        }
    }

    $outputPath = Join-Path $authDir $file.Name
    $finalLines | Set-Content -LiteralPath $outputPath -Encoding UTF8
    $fullSize = [math]::Round($file.Length / 1KB, 1)
    $authItem = Get-Item -LiteralPath $outputPath
    $authSize = [math]::Round($authItem.Length / 1KB, 1)
    $ratioNumber = if ($file.Length -gt 0) { [math]::Round($authItem.Length / $file.Length * 100, 0) } else { 0 }
    $stats.Add([pscustomobject]@{ File=$file.Name; FullKB=$fullSize; AuthKB=$authSize; Ratio=$ratioNumber; Stripped=$stripped }) | Out-Null
}

$lowRetention = @($stats | Where-Object { $_.Ratio -lt 40 })
$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Authority View Extraction Report') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Source: ``$fullDir``") | Out-Null
$report.Add("- Output: ``$authDir``") | Out-Null
$report.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$report.Add('- VERDICT: **PASS**') | Out-Null
$report.Add('') | Out-Null
$report.Add('| File | Full KB | Authority KB | Retained | Tagged paragraphs stripped |') | Out-Null
$report.Add('|---|---:|---:|---:|---:|') | Out-Null
foreach ($s in $stats) { $report.Add("| $($s.File) | $($s.FullKB) | $($s.AuthKB) | $($s.Ratio)% | $($s.Stripped) |") | Out-Null }
$report.Add('') | Out-Null
$report.Add('## Warnings') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Files below 40% retention: **$($lowRetention.Count)**") | Out-Null
foreach ($s in $lowRetention) { $report.Add("  - $($s.File): $($s.Ratio)% retained") | Out-Null }
$report -join "`n" | Set-Content -LiteralPath $reportPath -Encoding UTF8

$totalFull = [math]::Round(($stats | Measure-Object -Property FullKB -Sum).Sum, 1)
$totalAuth = [math]::Round(($stats | Measure-Object -Property AuthKB -Sum).Sum, 1)
$totalRatio = if ($totalFull -gt 0) { [math]::Round($totalAuth / $totalFull * 100, 0) } else { 0 }
$totalStripped = ($stats | Measure-Object -Property Stripped -Sum).Sum

Write-Host "Authority extraction complete. Source: $fullDir Output: $authDir"
Write-Host "Total: $totalFull KB (full) -> $totalAuth KB (authority) = $totalRatio% retained"
Write-Host "Paragraphs stripped: $totalStripped"
Write-Host "Report: $reportPath"
if ($lowRetention.Count -gt 0) { Write-Host "Warning: $($lowRetention.Count) file(s) below 40% retention." }
exit 0
