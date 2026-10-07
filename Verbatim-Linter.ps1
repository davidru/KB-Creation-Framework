<#
.SYNOPSIS
    Verbatim-Linter.ps1 — v3 mainline promotion of the pilot verbatim linter.

.DESCRIPTION
    Promoted from pilots\Modular - Updated Architecture\Verbatim-Linter.ps1 to
    the KB Creation Framework v3 mainline. Compares definitional and operative
    blockquotes in KB files against fetched primary-source markdown recorded in
    grounding\fetch_log.json. Flags paraphrase-drops, limb-drops,
    wrong-anchor citations, and misattributions.

.PARAMETER KBRoot
    KB root directory. When supplied without FullPath, FullPath defaults to
    $KBRoot\full and GroundingDir defaults to $KBRoot\grounding. Alias: KbPath
    for backward compatibility with the pilot script.

.PARAMETER FullPath
    Directory containing Markdown files to lint. Defaults to $KBRoot\full.

.PARAMETER GroundingDir
    Directory containing fetch_log.json and fetched source files. Defaults to
    $KBRoot\grounding.

.PARAMETER OutPath
    Path to write the Markdown findings report.

.PARAMETER MaxBracketWords
    Maximum number of words allowed in a bracketed editorial insertion `[...]`
    when matching a quote against the source. Default 8.

.PARAMETER MinQuoteLength
    Minimum quoted-text length in characters to lint. Default 40.

.EXITCODES
    0 = PASS / no findings.
    1 = FINDINGS / NEEDS-FETCH entries only.
    2 = BLOCKING / FLAGGED verbatim mismatches.

.RELATED
    KB Creation - Modular v3\07-audit-system.md — mechanical fidelity checks and scorecard inputs.
#>

[CmdletBinding()]
param(
    [Alias('KbPath')][string]$KBRoot = '',
    [string]$FullPath = '',
    [string]$GroundingDir = '',
    [Parameter(Mandatory=$true)][string]$OutPath,
    [int]$MaxBracketWords = 8,
    [int]$MinQuoteLength = 40
)

$ErrorActionPreference = 'Stop'

function Normalize-Whitespace {
    param([string]$Text)
    if (-not $Text) { return '' }
    $Text = $Text -replace [char]0x2018, "'" -replace [char]0x2019, "'"
    $Text = $Text -replace [char]0x201C, '"' -replace [char]0x201D, '"'
    $Text = $Text -replace [char]0x2013, '-' -replace [char]0x2014, '-'
    $Text = $Text -replace [char]0x00A0, ' '
    $Text = $Text -replace [char]0x2026, '...'
    return (($Text -replace '\s+', ' ').Trim())
}

function Strip-Bracketed-Inserts {
    param([string]$Text, [int]$MaxWords)
    return [regex]::Replace($Text, '\[([^\[\]]{1,200})\]', {
        param($m)
        $inside = $m.Groups[1].Value
        $words = @($inside -split '\s+' | Where-Object { $_ }).Count
        if ($words -le $MaxWords) { return '<<INSERT>>' }
        return $m.Value
    })
}

function Substring-Match {
    param([string]$Quote, [string]$Source)
    $q = Normalize-Whitespace (Strip-Bracketed-Inserts $Quote $MaxBracketWords)
    $s = Normalize-Whitespace $Source
    if ($q.Length -lt $MinQuoteLength) { return @{ Matched=$true; Reason='SKIPPED_TOO_SHORT' } }
    $escaped = [regex]::Escape($q)
    $escaped = $escaped -replace '\\\.\\\.\\\.', '.{0,300}?'
    $escaped = $escaped -replace '<<INSERT>>', '.{1,80}?'
    if ($s -match $escaped) { return @{ Matched=$true; Reason='OK' } }
    $head = if ($q.Length -gt 60) { $q.Substring(0, 60) } else { $q }
    $headEsc = [regex]::Escape($head) -replace '\\\.\\\.\\\.', '.{0,300}?' -replace '<<INSERT>>', '.{1,80}?'
    if ($s -match $headEsc) { return @{ Matched=$false; Reason='PARTIAL_HEAD_MATCH'; HeadMatch=$true } }
    return @{ Matched=$false; Reason='NO_MATCH'; HeadMatch=$false }
}

function Extract-Blockquotes {
    param([string]$FilePath)
    $content = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
    $lines = $content -split "`r?`n"
    $blocks = New-Object System.Collections.Generic.List[psobject]
    $current = New-Object System.Collections.Generic.List[string]
    $startLine = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*>\s?(.*)$') {
            if ($startLine -eq -1) { $startLine = $i + 1 }
            $current.Add($matches[1]) | Out-Null
        } else {
            if ($current.Count -gt 0) {
                $blocks.Add([pscustomobject]@{ StartLine=$startLine; EndLine=$i; Text=($current -join "`n").Trim() }) | Out-Null
                $current.Clear()
                $startLine = -1
            }
        }
    }
    if ($current.Count -gt 0) { $blocks.Add([pscustomobject]@{ StartLine=$startLine; EndLine=$lines.Count; Text=($current -join "`n").Trim() }) | Out-Null }
    return @($blocks)
}

function Find-CiteContext {
    param([string]$FilePath, [int]$EndLine, [int]$LookAround = 5)
    $content = Get-Content -LiteralPath $FilePath -Encoding UTF8
    if ($content.Count -eq 0) { return @() }
    $startContext = [Math]::Max(0, $EndLine - $LookAround)
    $endContext = [Math]::Min($content.Count - 1, $EndLine + $LookAround)
    $context = ($content[$startContext..$endContext] -join "`n")
    return @([regex]::Matches($context, 'https?://[^\s\)\]]+') | ForEach-Object { $_.Value.TrimEnd('.',',',';',')',']') } | Select-Object -Unique)
}

function Resolve-EntryPath {
    param($Entry, [string]$GroundingRoot)
    foreach ($prop in @('out_path','local_path','path')) {
        if ($Entry.PSObject.Properties.Name -contains $prop -and $Entry.$prop) {
            $candidate = [string]$Entry.$prop
            if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
            $joined = Join-Path $GroundingRoot $candidate
            if (Test-Path -LiteralPath $joined) { return (Resolve-Path -LiteralPath $joined).Path }
        }
    }
    return $null
}

if (-not $KBRoot -and -not $FullPath) { throw 'Either -KBRoot (alias -KbPath) or -FullPath is required.' }
if ($KBRoot) { $KBRoot = (Resolve-Path -LiteralPath $KBRoot).Path }
if (-not $FullPath) {
    $candidate = Join-Path $KBRoot 'full'
    $FullPath = if (Test-Path -LiteralPath $candidate) { $candidate } else { $KBRoot }
}
if (-not (Test-Path -LiteralPath $FullPath)) { throw "FullPath not found: $FullPath" }
$FullPath = (Resolve-Path -LiteralPath $FullPath).Path
if (-not $KBRoot) {
    $fullItem = Get-Item -LiteralPath $FullPath
    $KBRoot = if ($fullItem.Name -eq 'full') { $fullItem.Parent.FullName } else { $FullPath }
}
if (-not $GroundingDir) { $GroundingDir = Join-Path $KBRoot 'grounding' }
$manifestPath = Join-Path $GroundingDir 'fetch_log.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "fetch_log.json not found at $manifestPath. Run the Crawl4AI adapter first." }

Write-Host "Loading fetch manifest: $manifestPath"
$manifest = @(Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json)
$urlToText = @{}
$urlToHash = @{}
foreach ($entry in $manifest) {
    $ok = ($entry.PSObject.Properties.Name -notcontains 'ok') -or ($entry.ok -eq $true)
    if (-not $ok -or -not $entry.url) { continue }
    $sourcePath = Resolve-EntryPath -Entry $entry -GroundingRoot $GroundingDir
    if ($sourcePath) {
        $urlToText[[string]$entry.url] = (Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8)
        if ($entry.PSObject.Properties.Name -contains 'hash') { $urlToHash[[string]$entry.url] = $entry.hash }
        elseif ($entry.PSObject.Properties.Name -contains 'sha256') { $urlToHash[[string]$entry.url] = $entry.sha256 }
    }
}
Write-Host "Loaded $($urlToText.Count) fetched sources from manifest."

$baseForRelative = $FullPath
$mdFiles = @(Get-ChildItem -LiteralPath $FullPath -Recurse -Filter '*.md' -File |
    Where-Object { $_.FullName.Substring($baseForRelative.Length) -notmatch '\\(grounding|sources|notes|learned)\\' })
Write-Host "Linting $($mdFiles.Count) files..."

$findings = New-Object System.Collections.Generic.List[psobject]
$totalBlocks = 0
$skipped = 0
$matched = 0
$mismatched = 0
$noManifest = 0

foreach ($file in $mdFiles) {
    $blocks = @(Extract-Blockquotes -FilePath $file.FullName)
    foreach ($block in $blocks) {
        if ($block.Text.Length -lt $MinQuoteLength) { $skipped++; continue }
        $totalBlocks++
        $urls = @(Find-CiteContext -FilePath $file.FullName -EndLine $block.EndLine)
        if ($urls.Count -eq 0) { $skipped++; continue }
        $bestResult = $null
        $bestUrl = $null
        foreach ($url in $urls) {
            if (-not $urlToText.ContainsKey($url)) { continue }
            $result = Substring-Match -Quote $block.Text -Source $urlToText[$url]
            if ($null -eq $bestResult -or $result.Matched) {
                $bestResult = $result
                $bestUrl = $url
                if ($result.Matched) { break }
            }
        }
        $relativeFile = $file.FullName.Substring($baseForRelative.Length).TrimStart('\','/')
        if ($null -eq $bestResult) {
            $noManifest++
            $findings.Add([pscustomobject]@{
                File=$relativeFile; Line=$block.StartLine; Severity='NEEDS-FETCH'; Category='no-manifest'
                Quote=$block.Text.Substring(0, [Math]::Min(120, $block.Text.Length)); Urls=($urls -join '; ')
                Note='Cited URL(s) not found in fetch manifest. Re-run the Crawl4AI grounding adapter.'
            }) | Out-Null
            continue
        }
        if ($bestResult.Matched) {
            $matched++
        } else {
            $mismatched++
            $cat = if ($bestResult.HeadMatch) { 'LIMB-DROP-CANDIDATE' } else { 'WRONG-ANCHOR-CANDIDATE' }
            $findings.Add([pscustomobject]@{
                File=$relativeFile; Line=$block.StartLine; Severity='FLAGGED'; Category=$cat
                Quote=$block.Text.Substring(0, [Math]::Min(200, $block.Text.Length)); Urls=$bestUrl; Note=$bestResult.Reason
            }) | Out-Null
        }
    }
}

$report = @"
# Verbatim Linter — Findings Report
**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**KB root:** $KBRoot
**Full path:** $FullPath
**Manifest:** $manifestPath
**Files linted:** $($mdFiles.Count)
**Blockquotes scanned:** $totalBlocks (skipped $skipped without anchor URL or below min length)

## Summary

| Outcome | Count |
|---|---:|
| Matched (verbatim or restated within tolerance) | $matched |
| Flagged (paraphrase-drop / wrong-anchor / limb-drop) | $mismatched |
| NEEDS-FETCH (cited URL not in manifest) | $noManifest |

**Disposition:** Findings with severity ``FLAGGED`` should be remediated before ship. Either (a) replace the paraphrase with a verbatim blockquote of the cited source, (b) attribute as ``[Restated, not verbatim]`` per the Definitional Fidelity rule's structured-restatement relief valve, or (c) correct the cite if the wrong anchor is the issue.

## Findings (FLAGGED)

"@

$flagged = @($findings | Where-Object { $_.Severity -eq 'FLAGGED' })
if ($flagged.Count -eq 0) {
    $report += "*No flagged findings — all definitional/operative blockquotes substring-match their cited sources.*`n`n"
} else {
    foreach ($f in $flagged) {
        $report += "### $($f.File) (line $($f.Line)) — $($f.Category)`n"
        $report += "**URL:** $($f.Urls)`n"
        $report += "**Quote:**`n> $($f.Quote)`n`n"
        $report += "**Reason:** $($f.Note)`n`n---`n`n"
    }
}

$report += "## Findings (NEEDS-FETCH)`n`n"
$nf = @($findings | Where-Object { $_.Severity -eq 'NEEDS-FETCH' })
if ($nf.Count -eq 0) {
    $report += "*All anchor-cited blockquotes had a corresponding manifest entry.*`n`n"
} else {
    foreach ($f in $nf) { $report += "- ``$($f.File)`` line $($f.Line) — URL(s) not in manifest: $($f.Urls)`n" }
    $report += "`n"
}

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$report | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host "Done. Matched: $matched Flagged: $mismatched Needs-fetch: $noManifest Report: $OutPath"
if ($mismatched -gt 0) { exit 2 }
if ($noManifest -gt 0) { exit 1 }
exit 0
