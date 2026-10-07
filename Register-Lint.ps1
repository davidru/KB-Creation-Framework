<#
.SYNOPSIS
    Register-Lint.ps1 — v3 guidance/interpretion register-tag signal linter.

.DESCRIPTION
    Scans KB full/*.md for paragraphs containing guidance-language signals that
    are not tagged with <!-- [GUIDANCE] --> or <!-- [INTERPRETATION] -->. v3
    extends the signal vocabulary and can optionally scan root AGENTS.md,
    index.md, and table-of-authorities.md so guidance leakage outside full/ is
    visible before extraction and scorecard generation.

.PARAMETER FullPath
    Path to the KB full/ directory.

.PARAMETER OutPath
    Path to write the Markdown register-lint report.

.PARAMETER IncludeRootFiles
    When present, also scan AGENTS.md, index.md, and table-of-authorities.md at
    the KB root (the parent of FullPath). The report includes a Scope column.

.EXITCODES
    0 = PASS / no flagged paragraphs.
    1 = FINDINGS / non-blocking flagged paragraphs present.
    2 = BLOCKING / input path missing or report write failure.

.RELATED
    KB Creation - Modular v3\07-audit-system.md — Quality Scorecard register-tag coverage dimension.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FullPath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [switch]$IncludeRootFiles
)

$ErrorActionPreference = 'Stop'

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

# Guidance-language signal patterns (case-insensitive).
# Each entry is a regex; matches flag the paragraph for Lead review.
$signals = @(
    'as a practical matter',
    'the defensible response',
    'best practice(s)?',
    'experienced (practitioners|counsel)',
    'typically (advise|advis|include|recommend|require|involv|treat)',
    'generally recommended',
    'the better approach',
    'should (consider|evaluate|assess|review|identify)',
    'one approach is',
    'a common approach',
    'in our experience',
    '\bwe recommend\b',
    '\bI recommend\b',
    'rule of thumb',
    'practitioners (typically|generally|often)',
    'in practice,',
    'should (ensure|include|maintain|document|establish|verify|confirm|obtain|notify|retain|monitor)',
    '\bcounsel should\b',
    '\bpractitioners should\b',
    '\bclients should\b'
)

$signalRegex = ($signals -join '|')
$tagRegex = '<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->'

try {
    if (-not (Test-Path -LiteralPath $FullPath)) { throw "FullPath not found: $FullPath" }
    $kbRoot = Split-Path -Parent (Resolve-Path -LiteralPath $FullPath).Path
    $scanFiles = New-Object System.Collections.Generic.List[psobject]

    foreach ($file in @(Get-ChildItem -LiteralPath $FullPath -Filter '*.md' -File)) {
        $scanFiles.Add([pscustomobject]@{ Scope='full'; File=$file }) | Out-Null
    }

    if ($IncludeRootFiles) {
        foreach ($name in @('AGENTS.md','index.md','table-of-authorities.md')) {
            $rootFile = Join-Path $kbRoot $name
            if (Test-Path -LiteralPath $rootFile) {
                $scanFiles.Add([pscustomobject]@{ Scope='root'; File=(Get-Item -LiteralPath $rootFile) }) | Out-Null
            }
        }
    }

    $report = New-Object System.Collections.Generic.List[psobject]
    $counter = 0

    foreach ($item in $scanFiles) {
        $file = $item.File
        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        $paraStart = 1
        $para = New-Object System.Text.StringBuilder
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) {
                if ($para.Length -gt 0) {
                    $paraText = $para.ToString()
                    if ($paraText -notmatch $tagRegex -and $paraText -imatch $signalRegex) {
                        $matched = ([regex]::Matches($paraText, $signalRegex, 'IgnoreCase') | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', '
                        $excerpt = if ($paraText.Length -gt 400) { $paraText.Substring(0, 400) + '...' } else { $paraText }
                        $counter++
                        $report.Add([pscustomobject]@{ Num=$counter; Scope=$item.Scope; File=$file.Name; Line=$paraStart; Signal=$matched; Excerpt=$excerpt }) | Out-Null
                    }
                    $para.Clear() | Out-Null
                }
                $paraStart = $i + 2
            } else {
                if ($para.Length -gt 0) { $para.Append("`n") | Out-Null }
                $para.Append($line) | Out-Null
            }
        }
        if ($para.Length -gt 0) {
            $paraText = $para.ToString()
            if ($paraText -notmatch $tagRegex -and $paraText -imatch $signalRegex) {
                $matched = ([regex]::Matches($paraText, $signalRegex, 'IgnoreCase') | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', '
                $excerpt = if ($paraText.Length -gt 400) { $paraText.Substring(0, 400) + '...' } else { $paraText }
                $counter++
                $report.Add([pscustomobject]@{ Num=$counter; Scope=$item.Scope; File=$file.Name; Line=$paraStart; Signal=$matched; Excerpt=$excerpt }) | Out-Null
            }
        }
    }

    $md = New-Object System.Collections.Generic.List[string]
    $md.Add('# Register Lint Report') | Out-Null
    $md.Add('') | Out-Null
    $md.Add("**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $md.Add("**Source:** $FullPath") | Out-Null
    $md.Add("**Include root files:** $($IncludeRootFiles.IsPresent)") | Out-Null
    $md.Add("**Files scanned:** $($scanFiles.Count)") | Out-Null
    $md.Add("**Paragraphs flagged:** $counter") | Out-Null
    $md.Add('') | Out-Null
    $md.Add('Each flagged paragraph contains a guidance-language signal but is NOT tagged as <!-- [GUIDANCE] --> or <!-- [INTERPRETATION] -->. Lead must review every entry and either re-tag the paragraph or document why the paragraph is correctly untagged authority.') | Out-Null
    $md.Add('') | Out-Null
    $md.Add('Default lean: when in doubt, tag as GUIDANCE. See prompts/11c-register-lint.md or its v3 successor.') | Out-Null
    $md.Add('') | Out-Null
    $md.Add('| # | Scope | File | Line | Signal | Paragraph (excerpt) | Disposition | Rationale (if KEEP) |') | Out-Null
    $md.Add('|---|---|---|---:|---|---|---|---|') | Out-Null
    foreach ($row in $report) {
        $md.Add("| $($row.Num) | $($row.Scope) | $($row.File) | $($row.Line) | $(Escape-Md $row.Signal) | $(Escape-Md $row.Excerpt) | | |") | Out-Null
    }

    $outDir = Split-Path -Parent $OutPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $md -join "`n" | Set-Content -LiteralPath $OutPath -Encoding UTF8

    Write-Host "Register-lint complete. Files scanned: $($scanFiles.Count). Paragraphs flagged: $counter. Report: $OutPath"
    if ($counter -eq 0) {
        Write-Host 'No flagged paragraphs. Verify by spot-checking 2-3 files for guidance-language passages if this is unexpected.'
        exit 0
    }
    exit 1
} catch {
    Write-Error $_.Exception.Message
    exit 2
}
