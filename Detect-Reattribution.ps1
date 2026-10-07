<#
.SYNOPSIS
    Detect-Reattribution.ps1 — memo claim-map paraphrase/source alignment check.

.DESCRIPTION
    Companion to Detect-MemoLeakage.ps1 for the Memo Drafting Framework and KB
    Creation Framework v3 Phase 8 integration. Leakage detects fabricated
    specifics; reattribution detects likely misattributed specifics, where a
    memo cites a real claim_id but the paraphrase appears to contain distinctive
    content not present in that claim's source_quote.

.PARAMETER MemoPath
    Path to the Markdown memo containing a CLAIM MAP table.

.PARAMETER ClaimsPath
    Path to the JSON claims manifest produced by the claim extractor.

.PARAMETER OutPath
    Path to write the Markdown reattribution report.

.EXITCODES
    0 = CLEAN / no flags.
    1 = FINDINGS / one or more rows require writer review.

.RELATED
    Memo Drafting Framework v1\01-axioms.md; KB Creation - Modular v3\07-audit-system.md.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$MemoPath,
    [Parameter(Mandatory=$true)][string]$ClaimsPath,
    [Parameter(Mandatory=$true)][string]$OutPath
)

$ErrorActionPreference = 'Stop'

function Normalize-Text {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text.ToLowerInvariant() -replace '\s+', ' ').Trim())
}

function Get-Sha256 {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
}

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

function Split-MarkdownRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
    if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
    return @($trimmed -split '(?<!\\)\|' | ForEach-Object { $_.Trim() })
}

function Get-ClaimMapRows {
    param([string[]]$Lines)
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '(?i)claim\s+map') { $start = $i; break }
    }
    if ($start -lt 0) { return @() }

    $headerIndex = -1
    for ($i = $start; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\|' -and $Lines[$i] -match '(?i)claim[_ -]?id' -and $Lines[$i] -match '(?i)memo\s+statement') {
            $headerIndex = $i
            break
        }
    }
    if ($headerIndex -lt 0) { return @() }

    $headers = @(Split-MarkdownRow $Lines[$headerIndex] | ForEach-Object { ($_ -replace '<[^>]+>','' -replace '\*','').Trim().ToLowerInvariant() })
    $idxNumber = [array]::IndexOf($headers, '#')
    $idxStatement = -1
    $idxClaim = -1
    $idxMode = -1
    for ($i = 0; $i -lt $headers.Count; $i++) {
        if ($headers[$i] -match 'memo\s+statement') { $idxStatement = $i }
        if ($headers[$i] -match 'claim[_ -]?id') { $idxClaim = $i }
        if ($headers[$i] -match 'verbatim|paraphrased') { $idxMode = $i }
    }
    if ($idxStatement -lt 0 -or $idxClaim -lt 0 -or $idxMode -lt 0) { return @() }

    $rows = New-Object System.Collections.Generic.List[psobject]
    for ($i = $headerIndex + 2; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line -notmatch '^\s*\|') { break }
        $cells = @(Split-MarkdownRow $line)
        if ($cells.Count -lt $headers.Count) { continue }
        $rows.Add([pscustomobject]@{
            Number = if ($idxNumber -ge 0) { $cells[$idxNumber] } else { [string]($rows.Count + 1) }
            Statement = $cells[$idxStatement]
            ClaimId = $cells[$idxClaim]
            Mode = $cells[$idxMode]
        }) | Out-Null
    }
    return @($rows)
}

function Get-DistinctiveTokens {
    param([string]$Text)
    $tokens = New-Object System.Collections.Generic.List[string]

    $patterns = @(
        '\$\s?\d[\d,]*(?:\.\d+)?(?:\s?(?:million|billion|trillion|M|B|T|MM))?',
        '\b\d+(?:\.\d+)?\s?%',
        '\b\d{4}-\d{2}-\d{2}\b',
        '\b\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}\b',
        '§\s*[\dA-Za-z][\dA-Za-z.\-()]*',
        '\b\d+\s+U\.?S\.?C\.?\s*§?\s*[\dA-Za-z.\-()]+',
        '\b\d+\s+C\.?F\.?R\.?\s*(?:Part\s*)?[\dA-Za-z.\-()]+',
        '\bArt(?:icle)?\.?\s*\d+(?:\(\d+\))?(?:\([a-z]\))?'
    )
    foreach ($p in $patterns) {
        foreach ($m in [regex]::Matches($Text, $p, 'IgnoreCase')) { $tokens.Add($m.Value.Trim()) | Out-Null }
    }

    foreach ($m in [regex]::Matches($Text, '\b[A-Z][A-Za-z0-9&.\-]*(?:\s+[A-Z][A-Za-z0-9&.\-]*){1,5}\b')) {
        $value = $m.Value.Trim()
        if ($value -notmatch '^(The|This|That|For|Because|Claim|Memo)\b') { $tokens.Add($value) | Out-Null }
    }
    foreach ($m in [regex]::Matches($Text, '\b\d{3,}\b')) { $tokens.Add($m.Value.Trim()) | Out-Null }

    $stop = @('The','This','That','These','Those','Section','Article','Rule','Claim','Memo') | ForEach-Object { $_.ToLowerInvariant() }
    return @($tokens | Where-Object { $_ -and $stop -notcontains $_.ToLowerInvariant() } | Select-Object -Unique | Select-Object -First 12)
}

function Test-TokenInSource {
    param([string]$Token, [string]$Source)
    $needle = Normalize-Text $Token
    $haystack = Normalize-Text $Source
    if ($needle.Length -eq 0) { return $true }
    if ($haystack.Contains($needle)) { return $true }

    $looseNeedle = $needle -replace '[^a-z0-9]', ''
    $looseHaystack = $haystack -replace '[^a-z0-9]', ''
    if ($looseNeedle.Length -ge 3 -and $looseHaystack.Contains($looseNeedle)) { return $true }
    if ($looseNeedle.EndsWith('s') -and $looseNeedle.Length -gt 4 -and $looseHaystack.Contains($looseNeedle.Substring(0, $looseNeedle.Length - 1))) { return $true }
    return $false
}

if (-not (Test-Path -LiteralPath $MemoPath)) { throw "MemoPath not found: $MemoPath" }
if (-not (Test-Path -LiteralPath $ClaimsPath)) { throw "ClaimsPath not found: $ClaimsPath" }

$claimsJson = Get-Content -LiteralPath $ClaimsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$claimItems = if ($claimsJson.claims) { @($claimsJson.claims) } else { @($claimsJson) }
$sourceByClaim = @{}
foreach ($claim in $claimItems) {
    if ($claim.claim_id) { $sourceByClaim[[string]$claim.claim_id] = [string]$claim.source_quote }
}

$memoLines = Get-Content -LiteralPath $MemoPath -Encoding UTF8
$rows = @(Get-ClaimMapRows -Lines $memoLines)
$flags = New-Object System.Collections.Generic.List[psobject]

if ($rows.Count -eq 0) {
    $flags.Add([pscustomobject]@{ Number=''; ClaimId=''; Statement=''; SourceExcerpt=''; Reason='claim-map-not-found-or-malformed' }) | Out-Null
}

foreach ($row in $rows) {
    if ($row.Mode -notmatch '(?i)paraphrased') { continue }
    $claimId = ($row.ClaimId -replace '`','').Trim()
    if (-not $sourceByClaim.ContainsKey($claimId)) {
        $flags.Add([pscustomobject]@{ Number=$row.Number; ClaimId=$claimId; Statement=$row.Statement; SourceExcerpt=''; Reason='unresolved-claim-id' }) | Out-Null
        continue
    }

    $sourceQuote = $sourceByClaim[$claimId]
    $memoHash = Get-Sha256 (Normalize-Text $row.Statement)
    $sourceHash = Get-Sha256 (Normalize-Text $sourceQuote)
    $tokens = @(Get-DistinctiveTokens -Text $row.Statement)
    if ($tokens.Count -eq 0) { continue }

    $missing = @($tokens | Where-Object { -not (Test-TokenInSource -Token $_ -Source $sourceQuote) })
    $missingRatio = if ($tokens.Count -gt 0) { $missing.Count / $tokens.Count } else { 0 }
    if ($tokens.Count -ge 2 -and $missingRatio -ge 0.5) {
        $excerpt = if ($sourceQuote.Length -gt 220) { $sourceQuote.Substring(0, 220) + '...' } else { $sourceQuote }
        $flags.Add([pscustomobject]@{
            Number=$row.Number
            ClaimId=$claimId
            Statement=$row.Statement
            SourceExcerpt=$excerpt
            Reason="paraphrase-claims-content-not-in-source; missing distinctive tokens: $($missing -join ', '); memo_sha256=$($memoHash.Substring(0,12)); source_sha256=$($sourceHash.Substring(0,12))"
        }) | Out-Null
    }
}

$verdict = if ($flags.Count -eq 0) { 'CLEAN' } else { 'FINDINGS' }
$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Reattribution Detection Report') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Memo: ``$MemoPath``") | Out-Null
$report.Add("- Claims manifest: ``$ClaimsPath``") | Out-Null
$report.Add("- Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$report.Add("- CLAIM MAP rows parsed: **$($rows.Count)**") | Out-Null
$report.Add('') | Out-Null
$report.Add("## Verdict: **$verdict**") | Out-Null
$report.Add('') | Out-Null
$report.Add('| # | claim_id | Memo statement | source_quote excerpt | Reason flagged |') | Out-Null
$report.Add('|---|---|---|---|---|') | Out-Null
if ($flags.Count -eq 0) {
    $report.Add('| — | — | — | — | No likely reattribution flags detected. |') | Out-Null
} else {
    foreach ($flag in $flags) {
        $report.Add("| $(Escape-Md $flag.Number) | $(Escape-Md $flag.ClaimId) | $(Escape-Md $flag.Statement) | $(Escape-Md $flag.SourceExcerpt) | $(Escape-Md $flag.Reason) |") | Out-Null
    }
}
$report.Add('') | Out-Null
$report.Add('## Disposition instruction') | Out-Null
$report.Add('') | Out-Null
$report.Add("For each flag, the writer must either (a) restore the dropped specifics to align with source_quote, (b) replace with verbatim block quote of source_quote, or (c) re-extract a more comprehensive claim from the source corpus. Do NOT wave off because 'the paraphrase is substantively equivalent' — equivalent paraphrasing should not lose 50%+ of distinctive tokens.") | Out-Null

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$report -join "`n" | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host "Reattribution audit: $verdict — $($flags.Count) flag(s). Report at $OutPath"
if ($flags.Count -eq 0) { exit 0 } else { exit 1 }
