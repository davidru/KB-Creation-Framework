<#
.SYNOPSIS
    Validate-Phase4Inventory.ps1 — v3 Single-Source Claim Inventory schema validator.

.DESCRIPTION
    Mechanically validates the Phase 4 "Single-Source Claim Inventory" section
    in sources/comparison_report.md. The validator checks table presence,
    required columns, claim_id shape, required field population, originating
    builder values, and claim_type vocabulary. It is a blocking contract check.

.PARAMETER ComparisonReportPath
    Path to sources/comparison_report.md.

.PARAMETER OutPath
    Path to write the Markdown validation report.

.EXITCODES
    0 = PASS / inventory present and valid.
    2 = FAIL / missing section, malformed table, missing required column, or any
        row-level validation failure.

.RELATED
    KB Creation - Modular v3\03-builder.md — Phase 4 claim-inventory contract.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ComparisonReportPath,
    [Parameter(Mandatory=$true)][string]$OutPath
)

$ErrorActionPreference = 'Stop'

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

function Normalize-Header {
    param([string]$Header)
    return (($Header -replace '<[^>]+>','' -replace '\*','').Trim().ToLowerInvariant() -replace '\s+','_')
}

$findings = New-Object System.Collections.Generic.List[psobject]
$rowsParsed = 0
$tableRows = @()
$headers = @()

try {
    if (-not (Test-Path -LiteralPath $ComparisonReportPath)) { throw "ComparisonReportPath not found: $ComparisonReportPath" }
    $lines = Get-Content -LiteralPath $ComparisonReportPath -Encoding UTF8
    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##+\s+(Section\s+6\s*[\-—:]\s*)?Single[- ]Source\s+Claim\s+Inventory\s*$') { $sectionIndex = $i; break }
    }

    if ($sectionIndex -lt 0) {
        $findings.Add([pscustomobject]@{ Row='section'; Field='heading'; Problem='Single-Source Claim Inventory section not found.'; Value='' }) | Out-Null
    } else {
        $headerIndex = -1
        for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^##+\s+' -and $i -gt $sectionIndex + 1) { break }
            if ($lines[$i] -match '^\s*\|' -and $lines[$i] -match '(?i)claim[_ ]?id') { $headerIndex = $i; break }
        }

        if ($headerIndex -lt 0 -or $headerIndex + 1 -ge $lines.Count -or $lines[$headerIndex + 1] -notmatch '^\s*\|?\s*:?-{3,}') {
            $findings.Add([pscustomobject]@{ Row='table'; Field='table'; Problem='Inventory table missing or malformed beneath section heading.'; Value='' }) | Out-Null
        } else {
            $headers = @(Split-MarkdownRow $lines[$headerIndex] | ForEach-Object { Normalize-Header $_ })
            $requiredColumns = @('claim_id','claim_text','originating_builder','v2_location','claim_type','risk_notes')
            foreach ($col in $requiredColumns) {
                if ($headers -notcontains $col) {
                    $findings.Add([pscustomobject]@{ Row='header'; Field=$col; Problem='Required column missing.'; Value='' }) | Out-Null
                }
            }

            for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line -notmatch '^\s*\|') { break }
                $cells = @(Split-MarkdownRow $line)
                if ($cells.Count -lt $headers.Count) {
                    $findings.Add([pscustomobject]@{ Row=$rowsParsed + 1; Field='row'; Problem='Malformed row has fewer cells than header.'; Value=$line }) | Out-Null
                    continue
                }
                $rowMap = @{}
                for ($c = 0; $c -lt $headers.Count; $c++) { $rowMap[$headers[$c]] = $cells[$c] }
                $tableRows += $rowMap
            }
        }
    }

    $validClaimTypes = @('citation','date','number','entity','legal-status','classification','membership','institutional-fact','other')
    $rowsParsed = $tableRows.Count
    for ($r = 0; $r -lt $tableRows.Count; $r++) {
        $row = $tableRows[$r]
        $rowNumber = $r + 1
        if (-not $row.ContainsKey('claim_id') -or $row['claim_id'] -notmatch '^SSC-\d{4}$') {
            $findings.Add([pscustomobject]@{ Row=$rowNumber; Field='claim_id'; Problem='claim_id must match ^SSC-\d{4}$'; Value=if ($row.ContainsKey('claim_id')) { $row['claim_id'] } else { '' } }) | Out-Null
        }
        foreach ($field in @('claim_text','v2_location')) {
            if (-not $row.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($row[$field])) {
                $findings.Add([pscustomobject]@{ Row=$rowNumber; Field=$field; Problem='Field must be non-empty.'; Value='' }) | Out-Null
            }
        }
        if (-not $row.ContainsKey('originating_builder') -or $row['originating_builder'] -notin @('A','B')) {
            $findings.Add([pscustomobject]@{ Row=$rowNumber; Field='originating_builder'; Problem='originating_builder must be A or B.'; Value=if ($row.ContainsKey('originating_builder')) { $row['originating_builder'] } else { '' } }) | Out-Null
        }
        if (-not $row.ContainsKey('claim_type') -or $validClaimTypes -notcontains $row['claim_type']) {
            $findings.Add([pscustomobject]@{ Row=$rowNumber; Field='claim_type'; Problem="claim_type must be one of: $($validClaimTypes -join ', ')"; Value=if ($row.ContainsKey('claim_type')) { $row['claim_type'] } else { '' } }) | Out-Null
        }
    }

    if ($tableRows.Count -eq 0 -and $findings.Count -eq 0) {
        $findings.Add([pscustomobject]@{ Row='table'; Field='rows'; Problem='Inventory table contains no rows.'; Value='' }) | Out-Null
    }
} catch {
    $findings.Add([pscustomobject]@{ Row='script'; Field='exception'; Problem=$_.Exception.Message; Value='' }) | Out-Null
}

$verdict = if ($findings.Count -eq 0) { 'PASS' } else { 'FAIL' }
$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Phase 4 Single-Source Claim Inventory Validation') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Comparison report: ``$ComparisonReportPath``") | Out-Null
$report.Add("- Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$report.Add("- Rows parsed: **$rowsParsed**") | Out-Null
$report.Add("- Findings: **$($findings.Count)**") | Out-Null
$report.Add('') | Out-Null
$report.Add("## VERDICT: **$verdict**") | Out-Null
$report.Add('') | Out-Null
$report.Add('| Row | Field | Problem | Value |') | Out-Null
$report.Add('|---|---|---|---|') | Out-Null
if ($findings.Count -eq 0) {
    $report.Add('| — | — | — | Inventory schema is valid. |') | Out-Null
} else {
    foreach ($f in $findings) { $report.Add("| $(Escape-Md $f.Row) | $(Escape-Md $f.Field) | $(Escape-Md $f.Problem) | $(Escape-Md $f.Value) |") | Out-Null }
}

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$report -join "`n" | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Host "Phase 4 inventory validation: $verdict — $rowsParsed row(s), $($findings.Count) finding(s). Report at $OutPath"
if ($findings.Count -eq 0) { exit 0 } else { exit 2 }
