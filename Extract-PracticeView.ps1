<#
.SYNOPSIS
    Extract-PracticeView.ps1 — v3 middle-tier practice-view extractor.

.DESCRIPTION
    Produces the practice/ view from full/*.md by stripping only paragraphs tagged
    with <!-- [INTERPRETATION] --> while retaining <!-- [GUIDANCE] --> paragraphs.
    Uses the same continuation-line semantics as Extract-AuthorityView.ps1: a
    stripped tagged paragraph continues until a blank line, Markdown heading, or
    YAML delimiter. Generates a Markdown extraction report.

.PARAMETER KBRoot
    KB root directory. Reads $KBRoot\full\*.md and writes $KBRoot\practice\*.md.

.EXITCODES
    0 = PASS / extraction complete.
    1 = full/ missing or inline-position register tag rejected.
    2 = BLOCKING verification gate failure (no files or missing practice peer).

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
$practiceDir = Join-Path $KBRoot 'practice'
$sourcesDir = Join-Path $KBRoot 'sources'
$reportPath = Join-Path $sourcesDir 'practice_view_extraction.md'

if (-not (Test-Path -LiteralPath $sourcesDir)) { New-Item -ItemType Directory -Path $sourcesDir -Force | Out-Null }

if (-not (Test-Path -LiteralPath $fullDir)) {
    @("# Practice View Extraction Report", "", "## VERDICT: BLOCK", "", "full/ directory not found: ``$fullDir``") | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "Practice extraction blocked: full/ not found. Report at $reportPath"
    exit 1
}

$files = @(Get-ChildItem -LiteralPath $fullDir -Filter '*.md' -File)
$inlineFindings = @(Test-InlineRegisterTags -Files $files)
if ($inlineFindings.Count -gt 0) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Practice View Extraction Report') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## VERDICT: BLOCK') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('Inline-position register tags were found. Register tags must appear at the beginning of the tagged paragraph line before extraction.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| File | Line | Text |') | Out-Null
    $lines.Add('|---|---:|---|') | Out-Null
    foreach ($f in $inlineFindings) { $lines.Add("| $($f.File) | $($f.Line) | $(Escape-Md $f.Text) |") | Out-Null }
    $lines -join "`n" | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "Practice extraction blocked: $($inlineFindings.Count) inline register tag(s). Report at $reportPath"
    exit 1
}

if (-not (Test-Path -LiteralPath $practiceDir)) { New-Item -ItemType Directory -Path $practiceDir -Force | Out-Null }

$stats = New-Object System.Collections.Generic.List[psobject]
foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
    $outputLines = New-Object System.Collections.Generic.List[string]
    $stripped = 0
    $inStrippedBlock = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*<!--\s*\[INTERPRETATION\]\s*-->') {
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

    $outputPath = Join-Path $practiceDir $file.Name
    $finalLines | Set-Content -LiteralPath $outputPath -Encoding UTF8
    $fullSize = [math]::Round($file.Length / 1KB, 1)
    $practiceItem = Get-Item -LiteralPath $outputPath
    $practiceSize = [math]::Round($practiceItem.Length / 1KB, 1)
    $ratioNumber = if ($file.Length -gt 0) { [math]::Round($practiceItem.Length / $file.Length * 100, 0) } else { 0 }
    $stats.Add([pscustomobject]@{ File=$file.Name; FullKB=$fullSize; PracticeKB=$practiceSize; Ratio=$ratioNumber; Stripped=$stripped }) | Out-Null
}

$missingPeers = @($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $practiceDir $_.Name)) })
$lowRetention = @($stats | Where-Object { $_.Ratio -lt 60 })
$smallFiles = @($stats | Where-Object { $_.PracticeKB -lt 12 })
$verdict = if ($files.Count -eq 0 -or $missingPeers.Count -gt 0) { 'BLOCK' } else { 'PASS' }

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Practice View Extraction Report') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Source: ``$fullDir``") | Out-Null
$report.Add("- Output: ``$practiceDir``") | Out-Null
$report.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$report.Add("- VERDICT: **$verdict**") | Out-Null
$report.Add('') | Out-Null
$report.Add('| File | Full KB | Practice KB | Retained | Interpretation paragraphs stripped |') | Out-Null
$report.Add('|---|---:|---:|---:|---:|') | Out-Null
foreach ($s in $stats) { $report.Add("| $($s.File) | $($s.FullKB) | $($s.PracticeKB) | $($s.Ratio)% | $($s.Stripped) |") | Out-Null }
$report.Add('') | Out-Null
$report.Add('## Verification gates') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Full files discovered: **$($files.Count)**") | Out-Null
$report.Add("- Practice peers missing: **$($missingPeers.Count)**") | Out-Null
$report.Add("- Files below 60% retention (warning): **$($lowRetention.Count)**") | Out-Null
$report.Add("- Practice files below 12KB (warning): **$($smallFiles.Count)**") | Out-Null
if ($lowRetention.Count -gt 0) { foreach ($s in $lowRetention) { $report.Add("  - $($s.File): $($s.Ratio)% retained") | Out-Null } }
if ($smallFiles.Count -gt 0) { foreach ($s in $smallFiles) { $report.Add("  - $($s.File): $($s.PracticeKB) KB") | Out-Null } }
$report -join "`n" | Set-Content -LiteralPath $reportPath -Encoding UTF8

$totalFull = [math]::Round(($stats | Measure-Object -Property FullKB -Sum).Sum, 1)
$totalPractice = [math]::Round(($stats | Measure-Object -Property PracticeKB -Sum).Sum, 1)
Write-Host "Practice extraction: $verdict — $($files.Count) file(s), $totalFull KB -> $totalPractice KB. Report at $reportPath"
if ($verdict -eq 'PASS') { exit 0 } else { exit 2 }
