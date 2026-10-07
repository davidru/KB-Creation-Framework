<#
.SYNOPSIS
    Diff-KBVersions.ps1 — structured diff between two builds of the same KB.

.DESCRIPTION
    Compares full/*.md topic files between an old KB root/archive and a current
    KB root. Topics are matched by filename slug after an NN- prefix. The script
    extracts claim-like paragraphs (citations, statute references, dates,
    dollar amounts, percentages, or section references), classifies per-claim
    changes heuristically, computes a drift index, and writes a Markdown report.

.PARAMETER OldPath
    Path to old KB root or archived _v*_archive_* directory.

.PARAMETER NewPath
    Path to current KB root.

.PARAMETER OutPath
    Path to write the Markdown diff report.

.EXITCODES
    0 = report written. This is an advisory reporting tool and never blocks.

.RELATED
    KB Creation - Modular v3\06-refresh-orchestrator.md — refresh confidence and downstream notification.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OldPath,
    [Parameter(Mandatory=$true)][string]$NewPath,
    [Parameter(Mandatory=$true)][string]$OutPath
)

$ErrorActionPreference = 'Stop'

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

function Get-FullDir {
    param([string]$Root)
    $candidate = Join-Path $Root 'full'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $Root
}

function Get-Slug {
    param([string]$Name)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)
    return ($base -replace '^\d{1,3}[-_\s]+','').ToLowerInvariant()
}

function Normalize-Text {
    param([string]$Text)
    return (($Text.ToLowerInvariant() -replace '<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->','' -replace '[^a-z0-9§%$\.]+',' ' -replace '\s+',' ').Trim())
}

function Get-Registers {
    param([string]$Text)
    $tags = @()
    if ($Text -match '<!--\s*\[GUIDANCE\]\s*-->') { $tags += 'GUIDANCE' }
    if ($Text -match '<!--\s*\[INTERPRETATION\]\s*-->') { $tags += 'INTERPRETATION' }
    if ($tags.Count -eq 0) { return 'UNTAGGED' }
    return ($tags -join '+')
}

function Get-ClaimAtoms {
    param([string]$Text)
    $patterns = @(
        '§\s*[\dA-Za-z][\dA-Za-z.\-()]*',
        '\b\d+\s+U\.?S\.?C\.?\s*§?\s*[\dA-Za-z.\-()]+',
        '\b\d+\s+C\.?F\.?R\.?\s*(?:Part\s*)?[\dA-Za-z.\-()]+',
        '\bArt(?:icle)?\.?\s*\d+(?:\(\d+\))?(?:\([a-z]\))?',
        '\$\s?\d[\d,]*(?:\.\d+)?(?:\s?(?:million|billion|trillion|M|B|T|MM))?',
        '\b\d+(?:\.\d+)?\s?%',
        '\b\d{4}-\d{2}-\d{2}\b',
        '\b\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}\b'
    )
    $atoms = @()
    foreach ($p in $patterns) { $atoms += [regex]::Matches($Text, $p, 'IgnoreCase') | ForEach-Object { Normalize-Text $_.Value } }
    return @($atoms | Select-Object -Unique)
}

function Get-SubjectSignature {
    param([string]$Text)
    $tokens = @(Normalize-Text $Text -split '\s+' | Where-Object { $_.Length -gt 2 -and $_ -notmatch '^\d+$' } | Select-Object -First 12)
    return (($tokens | Select-Object -First 6) -join ' ')
}

function Get-ClaimsFromFile {
    param([string]$Path, [string]$BaseDir)
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $paragraphs = @($content -split "(?:`r?`n){2,}")
    $claims = New-Object System.Collections.Generic.List[psobject]
    $lineCursor = 1
    foreach ($para in $paragraphs) {
        $hasClaimMarker = $para -match '§|\bU\.?S\.?C\.?\b|\bC\.?F\.?R\.?\b|\bArt(?:icle)?\.?\s*\d|\$\s?\d|\b\d+(?:\.\d+)?\s?%|\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
        if ($hasClaimMarker) {
            $atoms = @(Get-ClaimAtoms $para)
            $signature = if ($atoms.Count -gt 0) { ($atoms -join '|') } else { Get-SubjectSignature $para }
            $claims.Add([pscustomobject]@{
                File = $Path.Substring($BaseDir.Length).TrimStart('\','/')
                Line = $lineCursor
                Text = ($para.Trim() -replace "`r?`n", ' ')
                Normalized = Normalize-Text $para
                Register = Get-Registers $para
                Atoms = $atoms
                Signature = $signature
                Subject = Get-SubjectSignature $para
            }) | Out-Null
        }
        $lineCursor += (($para -split "`r?`n").Count + 1)
    }
    return @($claims)
}

function Get-TopicMap {
    param([string]$Root)
    $full = Get-FullDir $Root
    if (-not (Test-Path -LiteralPath $full)) { throw "full/ or topic directory not found: $Root" }
    $map = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $full -Filter '*.md' -File)) { $map[(Get-Slug $file.Name)] = $file }
    return @{ FullDir=$full; Map=$map }
}

$oldInfo = Get-TopicMap $OldPath
$newInfo = Get-TopicMap $NewPath
$oldMap = $oldInfo.Map
$newMap = $newInfo.Map
$allSlugs = @($oldMap.Keys + $newMap.Keys | Sort-Object -Unique)

$topicSummaries = New-Object System.Collections.Generic.List[psobject]
$detailRows = New-Object System.Collections.Generic.List[psobject]
$totals = [ordered]@{ 'UNCHANGED'=0; 'CHANGED-WORDING-SAME-MEANING'=0; 'CHANGED-MEANING'=0; 'REGISTER-RECLASSIFIED'=0; 'REMOVED'=0; 'ADDED'=0; 'NEW-TOPIC'=0; 'ADDED-IN-OLD-MISSING-IN-NEW'=0 }

foreach ($slug in $allSlugs) {
    if (-not $oldMap.ContainsKey($slug)) {
        $totals['NEW-TOPIC']++
        $topicSummaries.Add([pscustomobject]@{ Topic=$slug; Status='NEW-TOPIC'; Unchanged=0; Wording=0; Meaning=0; Register=0; Removed=0; Added=1 }) | Out-Null
        continue
    }
    if (-not $newMap.ContainsKey($slug)) {
        $totals['ADDED-IN-OLD-MISSING-IN-NEW']++
        $topicSummaries.Add([pscustomobject]@{ Topic=$slug; Status='ADDED-IN-OLD-MISSING-IN-NEW'; Unchanged=0; Wording=0; Meaning=0; Register=0; Removed=1; Added=0 }) | Out-Null
        continue
    }

    $oldClaims = @(Get-ClaimsFromFile -Path $oldMap[$slug].FullName -BaseDir $oldInfo.FullDir)
    $newClaims = @(Get-ClaimsFromFile -Path $newMap[$slug].FullName -BaseDir $newInfo.FullDir)
    $newBySignature = @{}
    foreach ($c in $newClaims) { if (-not $newBySignature.ContainsKey($c.Signature)) { $newBySignature[$c.Signature] = New-Object System.Collections.Generic.List[psobject] }; $newBySignature[$c.Signature].Add($c) | Out-Null }
    $matchedNew = New-Object System.Collections.Generic.HashSet[string]
    $counts = [ordered]@{ Unchanged=0; Wording=0; Meaning=0; Register=0; Removed=0; Added=0 }

    foreach ($old in $oldClaims) {
        $match = $null
        if ($newBySignature.ContainsKey($old.Signature)) { $match = @($newBySignature[$old.Signature])[0] }
        if ($null -eq $match) {
            $sameSubject = @($newClaims | Where-Object { $_.Subject -eq $old.Subject } | Select-Object -First 1)
            if ($sameSubject.Count -gt 0) { $match = $sameSubject[0] }
        }
        if ($null -eq $match) {
            $counts.Removed++; $totals['REMOVED']++
            $detailRows.Add([pscustomobject]@{ Topic=$slug; Category='REMOVED'; Old=$old.Text; New=''; Note='Claim-like paragraph present only in old version.' }) | Out-Null
            continue
        }
        $matchedNew.Add($match.Normalized) | Out-Null
        if ($old.Normalized -eq $match.Normalized -and $old.Register -eq $match.Register) {
            $counts.Unchanged++; $totals['UNCHANGED']++
        } elseif ($old.Normalized -eq $match.Normalized -and $old.Register -ne $match.Register) {
            $counts.Register++; $totals['REGISTER-RECLASSIFIED']++
            $detailRows.Add([pscustomobject]@{ Topic=$slug; Category='REGISTER-RECLASSIFIED'; Old=$old.Text; New=$match.Text; Note="Register changed: $($old.Register) -> $($match.Register)." }) | Out-Null
        } else {
            $oldAtoms = @($old.Atoms)
            $newAtoms = @($match.Atoms)
            $atomsSame = (($oldAtoms -join '|') -eq ($newAtoms -join '|'))
            if ($atomsSame) {
                $counts.Wording++; $totals['CHANGED-WORDING-SAME-MEANING']++
                $detailRows.Add([pscustomobject]@{ Topic=$slug; Category='CHANGED-WORDING-SAME-MEANING'; Old=$old.Text; New=$match.Text; Note='Cite/numeric atoms unchanged; narrative wording differs.' }) | Out-Null
            } else {
                $counts.Meaning++; $totals['CHANGED-MEANING']++
                $detailRows.Add([pscustomobject]@{ Topic=$slug; Category='CHANGED-MEANING'; Old=$old.Text; New=$match.Text; Note='Cite, date, amount, percentage, or section atom changed.' }) | Out-Null
            }
        }
    }

    foreach ($new in $newClaims) {
        if (-not $matchedNew.Contains($new.Normalized)) {
            $counts.Added++; $totals['ADDED']++
            $detailRows.Add([pscustomobject]@{ Topic=$slug; Category='ADDED'; Old=''; New=$new.Text; Note='Claim-like paragraph present only in new version.' }) | Out-Null
        }
    }

    $topicSummaries.Add([pscustomobject]@{ Topic=$slug; Status='COMPARED'; Unchanged=$counts.Unchanged; Wording=$counts.Wording; Meaning=$counts.Meaning; Register=$counts.Register; Removed=$counts.Removed; Added=$counts.Added }) | Out-Null
}

$totalClaims = [math]::Max(1, ($totals['UNCHANGED'] + $totals['CHANGED-WORDING-SAME-MEANING'] + $totals['CHANGED-MEANING'] + $totals['REGISTER-RECLASSIFIED'] + $totals['REMOVED'] + $totals['ADDED']))
$material = $totals['CHANGED-MEANING'] + $totals['REMOVED'] + $totals['ADDED'] + $totals['ADDED-IN-OLD-MISSING-IN-NEW'] + $totals['NEW-TOPIC']
$driftIndex = [math]::Round(($material / $totalClaims) * 100, 1)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# KB Version Diff Report') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("- Old path: ``$OldPath``") | Out-Null
$lines.Add("- New path: ``$NewPath``") | Out-Null
$lines.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- Drift index: **$driftIndex / 100** (% claim-like paragraphs changed materially)") | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## KB-wide totals') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Category | Count |') | Out-Null
$lines.Add('|---|---:|') | Out-Null
foreach ($key in $totals.Keys) { $lines.Add("| $key | $($totals[$key]) |") | Out-Null }
$lines.Add('') | Out-Null
$lines.Add('## Per-topic summary') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Topic | Status | Unchanged | Wording-only | Meaning | Register | Removed | Added |') | Out-Null
$lines.Add('|---|---|---:|---:|---:|---:|---:|---:|') | Out-Null
foreach ($t in $topicSummaries) { $lines.Add("| $($t.Topic) | $($t.Status) | $($t.Unchanged) | $($t.Wording) | $($t.Meaning) | $($t.Register) | $($t.Removed) | $($t.Added) |") | Out-Null }
$lines.Add('') | Out-Null
$lines.Add('## Material / reviewable claim diffs') | Out-Null
$lines.Add('') | Out-Null
if ($detailRows.Count -eq 0) {
    $lines.Add('_No claim-like diffs detected._') | Out-Null
} else {
    $lines.Add('| Topic | Category | Old excerpt | New excerpt | Note |') | Out-Null
    $lines.Add('|---|---|---|---|---|') | Out-Null
    foreach ($d in @($detailRows | Select-Object -First 200)) {
        $old = if ($d.Old.Length -gt 220) { $d.Old.Substring(0,220) + '...' } else { $d.Old }
        $new = if ($d.New.Length -gt 220) { $d.New.Substring(0,220) + '...' } else { $d.New }
        $lines.Add("| $($d.Topic) | $($d.Category) | $(Escape-Md $old) | $(Escape-Md $new) | $(Escape-Md $d.Note) |") | Out-Null
    }
    if ($detailRows.Count -gt 200) { $lines.Add("`n_Report truncated to first 200 detail rows; totals above include all $($detailRows.Count) rows._") | Out-Null }
}
$lines.Add('') | Out-Null
$lines.Add('## Suggested downstream-consumer notification text') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("> A refreshed KB version is available. Mechanical diff found a drift index of $driftIndex/100, with $($totals['CHANGED-MEANING']) changed-meaning claim(s), $($totals['ADDED']) added claim(s), and $($totals['REMOVED']) removed claim(s). Review the per-topic diff before relying on refreshed legal, regulatory, or institutional facts that changed materially.") | Out-Null

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$lines -join "`n" | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host "KB diff complete. Drift index: $driftIndex. Report: $OutPath"
exit 0
