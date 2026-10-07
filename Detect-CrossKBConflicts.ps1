<#
.SYNOPSIS
    Detect-CrossKBConflicts.ps1 — advisory cross-KB conflict detector.

.DESCRIPTION
    Scans KBs in a portfolio for claim atoms (statute citations, money amounts,
    percentages, dates, and named-entity sequences), groups them by a short
    subject signature, and flags groups where different KBs state different
    values for the same apparent subject. This is a high-recall worklist, not a
    correctness adjudication.

.PARAMETER PortfolioRoot
    Root containing KB directories. Defaults to the current directory.

.PARAMETER OutPath
    Path to write the Markdown conflict report.

.EXITCODES
    0 = no conflicts or INFO-tier conflicts only.
    1 = WARN-tier conflicts present.

.RELATED
    KB Creation - Modular v3\06-refresh-orchestrator.md — cross-KB portfolio hygiene.
#>

[CmdletBinding()]
param(
    [string]$PortfolioRoot = (Get-Location).Path,
    [Parameter(Mandatory=$true)][string]$OutPath
)

$ErrorActionPreference = 'Stop'

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

function Normalize-Value {
    param([string]$Value)
    return (($Value.ToLowerInvariant() -replace '\s+',' ' -replace '[,;\.]$','').Trim())
}

function Get-SubjectSignature {
    param([string]$Context)
    $codeLabels = @('u','s','c','usc','cfr','reg','regs','sec','section','article','art','rule','title','para','paragraph','subsection','clause','code','the','and','or','of','to','for','under','with')
    $tokens = @($Context -split '\W+' | Where-Object { $_ -match '\w' } | ForEach-Object { $_.ToLowerInvariant() } | Where-Object { $codeLabels -notcontains $_ -and $_ -notmatch '^\d+$' })
    return (($tokens | Select-Object -Last 6) -join ' ')
}

function Get-Severity {
    param([string]$Kind)
    switch ($Kind) {
        'cite' { return 'WARN' }
        'days' { return 'WARN' }
        'date' { return 'WARN' }
        'percentage' { return 'WARN' }
        'entity' { return 'WARN' }
        default { return 'INFO' }
    }
}

function Find-KBs {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { throw "PortfolioRoot not found: $Root" }
    $dirs = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $rootItem = Get-Item -LiteralPath $Root
    $dirs.Add($rootItem) | Out-Null
    foreach ($child in @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue)) {
        $dirs.Add($child) | Out-Null
        foreach ($grand in @(Get-ChildItem -LiteralPath $child.FullName -Directory -ErrorAction SilentlyContinue)) { $dirs.Add($grand) | Out-Null }
    }
    return @($dirs | Where-Object { (Test-Path -LiteralPath (Join-Path $_.FullName 'AGENTS.md')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'full')) } | Sort-Object FullName -Unique)
}

function Add-Atom {
    param($Atoms, [string]$Kind, [string]$Raw, [string]$Line, [int]$Index, [string]$KBName, [string]$KBPath, [string]$File, [int]$LineNumber)
    $start = [math]::Max(0, $Index - 90)
    $ctx = $Line.Substring($start, $Index - $start)
    $sig = Get-SubjectSignature $ctx
    if (-not $sig) { return }
    $Atoms.Add([pscustomobject]@{
        Kind=$Kind
        Subject=$sig
        Value=Normalize-Value $Raw
        Raw=$Raw
        KB=$KBName
        KBPath=$KBPath
        File=$File
        Line=$LineNumber
        Context=($ctx -replace '\s+',' ').Trim()
        Severity=Get-Severity $Kind
    }) | Out-Null
}

$patterns = @(
    @{ Kind='cite'; Regex='(?:§+\s*[\d\w\-\.]+(?:\s*(?:et\s+seq|\(\w+\)))?)|(?:\b\d+\s+U\.?S\.?C\.?\s*§?\s*[\dA-Za-z.\-()]+)|(?:\b\d+\s+C\.?F\.?R\.?\s*(?:Part\s*)?[\dA-Za-z.\-()]+)|(?:\bArt(?:icle)?\.?\s*\d+(?:\(\d+\))?(?:\([a-z]\))?)' },
    @{ Kind='dollar'; Regex='\$\s?[\d,]+(?:\.\d+)?\s?(?:million|billion|trillion|M\b|B\b|T\b|MM)?' },
    @{ Kind='eur'; Regex='EUR\s?[\d ,]+(?:\.\d+)?\s?(?:million|M\b|B\b)?' },
    @{ Kind='percentage'; Regex='\b\d+(?:\.\d+)?\s?%' },
    @{ Kind='days'; Regex='\b\d+\s+(?:calendar\s+days?|working\s+days?|business\s+days?|days?)\b' },
    @{ Kind='date'; Regex='\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}\b' },
    @{ Kind='entity'; Regex='\b[A-Z][A-Za-z0-9&.\-]+(?:\s+[A-Z][A-Za-z0-9&.\-]+){1,5}\b' }
)

$kbs = @(Find-KBs -Root $PortfolioRoot)
$atoms = New-Object System.Collections.Generic.List[psobject]

foreach ($kb in $kbs) {
    $full = Join-Path $kb.FullName 'full'
    foreach ($file in @(Get-ChildItem -LiteralPath $full -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
        $rel = $file.FullName.Substring($kb.FullName.Length).TrimStart('\','/')
        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            foreach ($p in $patterns) {
                foreach ($m in [regex]::Matches($line, $p.Regex)) {
                    $raw = $m.Value.Trim()
                    if ($p.Kind -eq 'entity' -and $raw -match '^(United States|European Union|Official Journal|Federal Register|Knowledge Base|Table Of|Phase|Section)') { continue }
                    Add-Atom -Atoms $atoms -Kind $p.Kind -Raw $raw -Line $line -Index $m.Index -KBName $kb.Name -KBPath $kb.FullName -File $rel -LineNumber ($i + 1)
                }
            }
        }
    }
}

$conflicts = New-Object System.Collections.Generic.List[psobject]
$groups = @($atoms | Where-Object { $_.Subject } | Group-Object Kind, Subject)
foreach ($g in $groups) {
    $distinctKbs = @($g.Group | Select-Object -ExpandProperty KBPath -Unique)
    if ($distinctKbs.Count -lt 2) { continue }
    $distinctValues = @($g.Group | Select-Object -ExpandProperty Value -Unique)
    if ($distinctValues.Count -lt 2) { continue }

    $kind = $g.Group[0].Kind
    $severity = Get-Severity $kind
    $variants = @()
    foreach ($value in $distinctValues) {
        $rep = $g.Group | Where-Object { $_.Value -eq $value } | Select-Object -First 1
        $variants += [pscustomobject]@{ KB=$rep.KB; KBPath=$rep.KBPath; Value=$rep.Raw; File="$($rep.File):$($rep.Line)" }
    }
    if (@($variants | Select-Object -ExpandProperty KBPath -Unique).Count -lt 2) { continue }

    for ($i = 0; $i -lt $variants.Count; $i++) {
        for ($j = $i + 1; $j -lt $variants.Count; $j++) {
            if ($variants[$i].KBPath -eq $variants[$j].KBPath) { continue }
            $conflicts.Add([pscustomobject]@{
                Severity=$severity
                Kind=$kind
                Subject=$g.Group[0].Subject
                KBA=$variants[$i].KB
                ValueA=$variants[$i].Value
                SourceA=$variants[$i].File
                KBB=$variants[$j].KB
                ValueB=$variants[$j].Value
                SourceB=$variants[$j].File
                SuggestedResolution='Verify both claims against their canonical primary source or canonical KB topic; update the stale/wrong KB and log the correction.'
            }) | Out-Null
        }
    }
}

$warnCount = @($conflicts | Where-Object { $_.Severity -eq 'WARN' }).Count
$infoCount = @($conflicts | Where-Object { $_.Severity -eq 'INFO' }).Count

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Cross-KB Conflict Report') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Portfolio root: ``$PortfolioRoot``") | Out-Null
$report.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$report.Add("- KBs scanned: **$($kbs.Count)**") | Out-Null
$report.Add("- Claim atoms extracted: **$($atoms.Count)**") | Out-Null
$report.Add('') | Out-Null
$report.Add('## Summary') | Out-Null
$report.Add('') | Out-Null
$report.Add('| Severity | Count |') | Out-Null
$report.Add('|---|---:|') | Out-Null
$report.Add("| WARN | $warnCount |") | Out-Null
$report.Add("| INFO | $infoCount |") | Out-Null
$report.Add('') | Out-Null
$report.Add('## Conflict candidates') | Out-Null
$report.Add('') | Out-Null
if ($conflicts.Count -eq 0) {
    $report.Add('_No cross-KB conflict candidates detected._') | Out-Null
} else {
    $report.Add('| Severity | Subject | KB-A | Value-A | KB-B | Value-B | Suggested resolution |') | Out-Null
    $report.Add('|---|---|---|---|---|---|---|') | Out-Null
    foreach ($c in @($conflicts | Sort-Object @{e='Severity';Descending=$true}, Kind, Subject | Select-Object -First 500)) {
        $a = "$($c.KBA) ($($c.SourceA))"
        $b = "$($c.KBB) ($($c.SourceB))"
        $report.Add("| $($c.Severity) | $(Escape-Md $c.Subject) | $(Escape-Md $a) | $(Escape-Md $c.ValueA) | $(Escape-Md $b) | $(Escape-Md $c.ValueB) | $(Escape-Md $c.SuggestedResolution) |") | Out-Null
    }
    if ($conflicts.Count -gt 500) { $report.Add("`n_Report truncated to first 500 conflict rows; summary includes all $($conflicts.Count)._") | Out-Null }
}

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$report -join "`n" | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host "Cross-KB conflict scan complete. WARN: $warnCount INFO: $infoCount. Report: $OutPath"
if ($warnCount -gt 0) { exit 1 } else { exit 0 }
