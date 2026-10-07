<#
.SYNOPSIS
    Generate-QualityScorecard.ps1 — v3.1 KB Quality Scorecard aggregator.

.DESCRIPTION
    Aggregates mechanical build artifacts into audit/kb-quality-scorecard.md,
    audit/kb-quality.json, and append-only audit/kb-quality-history.json. The
    script is deterministic and makes no model calls. Missing artifacts produce
    a partial BUILD-INCOMPLETE scorecard rather than a runtime failure.

    v3.1.9: Rule 19 (Model-Family Separation) is evaluated against per-phase
    ACTUALS recorded in sources/pipeline_state.md per Rule 20 (Model Provenance
    Honesty) — NOT against the intended Phase 0.0 assignment. The scorecard
    surfaces a Model Provenance section listing per-phase actuals, evaluates the
    canonical Rule 19 verification pairs, runs within-phase distinctness checks
    (Builder A vs Builder B; v3.1.6 Lead-as-Builder anti-pattern detector), and
    factors silent violations / insufficient data / acknowledged opt-outs into
    the composite verdict per audit-templates/kb-quality-dimensions.yaml policy.

.PARAMETER KBRoot
    KB root directory.

.PARAMETER WeightsPath
    Optional path to audit-templates/kb-quality-dimensions.yaml. If missing or
    unreadable, hardcoded v3 defaults are used.

.EXITCODES
    0 = PASS.
    1 = PASS-WITH-CAVEATS, CONDITIONAL, or BUILD-INCOMPLETE.
    2 = FAIL.

.RELATED
    01-shared-axioms.md Rule 19 (Model-Family Separation) and Rule 20 (Model Provenance Honesty).
    audit-templates/kb-quality-dimensions.yaml § family_separation_exception_handling.
    prompts/01-orchestrator.md MODEL ASSIGNMENT PLUMBING (per-phase actuals logging spec).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$KBRoot,
    [string]$WeightsPath = ''
)

$ErrorActionPreference = 'Stop'

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

function Get-TextOrNull {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) }
    return $null
}

function Test-Artifact {
    param([string]$Relative)
    $path = Join-Path $KBRoot $Relative
    return [pscustomobject]@{ Relative=$Relative; Path=$path; Exists=(Test-Path -LiteralPath $path) }
}

function Get-RegexCount {
    param([string]$Text, [string]$Pattern)
    if ($null -eq $Text) { return 0 }
    return ([regex]::Matches($Text, $Pattern, 'IgnoreCase')).Count
}

function Clamp-Score {
    param([double]$Value)
    return [int][math]::Max(0, [math]::Min(100, [math]::Round($Value, 0)))
}

function Get-Weights {
    param([string]$Path)
    # v3.1.15 — re-weighted defaults: test-set takes 0.10 from citation-density (0.05) + structural (0.0) + register (0.05).
    # v3.1.14 — citation-engine takes 0.10 from stress-test (0.05) + citation-density (0.05).
    $defaults = [ordered]@{
        'Citation density & primary-source rate' = 0.10
        'Register-tag coverage & extraction integrity' = 0.05
        'Cross-reference fidelity' = 0.15
        'Qualifier preservation' = 0.20
        'Volatile-tag coverage' = 0.05
        'Stress-test pass rate' = 0.20
        'Structural & size compliance' = 0.05
        'Citation-engine verification rate' = 0.10
        'Test-set passage rate' = 0.10
    }
    if (-not $Path) { $Path = Join-Path (Split-Path -Parent $PSCommandPath) 'audit-templates\kb-quality-dimensions.yaml' }
    if (-not (Test-Path -LiteralPath $Path)) { return $defaults }

    try {
        $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        foreach ($key in @($defaults.Keys)) {
            $slug = ($key.ToLowerInvariant() -replace '[^a-z0-9]+','_').Trim('_')
            if ($content -match "(?m)^\s*$([regex]::Escape($slug))\s*:\s*(0?\.\d+|1(?:\.0+)?)\s*$") {
                $defaults[$key] = [double]$matches[1]
            } elseif ($content -match "(?m)^\s*weight\s*:\s*(0?\.\d+|1(?:\.0+)?)\s*#\s*$([regex]::Escape($key))") {
                $defaults[$key] = [double]$matches[1]
            }
        }
    } catch {
        Write-Warning "Could not parse weights file '$Path'; using hardcoded defaults. $($_.Exception.Message)"
    }
    return $defaults
}

function New-Dimension {
    param([string]$Name, [int]$Score, [int]$Threshold, [string]$Method, [hashtable]$Data)
    $verdict = if ($Score -ge $Threshold) { 'PASS' } elseif ($Score -ge ($Threshold - 10)) { 'CAVEAT' } else { 'FAIL' }
    return [pscustomobject]@{ Name=$Name; Score=$Score; Threshold=$Threshold; Verdict=$verdict; Method=$Method; Data=$Data; FamilySeparationTag=$null }
}

function Get-PhaseProvenance {
    # Parses per-phase actuals from pipeline_state.yaml (v3.1.11+ preferred) or
    # pipeline_state.md (legacy) per Rule 20 (Model Provenance Honesty).
    # Each phase log entry must contain (within a delimited chunk):
    #   intended_handle:    <handle>
    #   actual_model_id:    <model id reported by adapter>
    #   actual_provider:    <provider reported by adapter / inferred from registry>
    #   actual_family:      <family from model-registry.yaml lookup>
    #   dispatch_status:    dispatched-as-intended | dispatched-with-substitution |
    #                       dispatched-after-override | failed-then-acknowledged-opt-out
    # Optional: phase id (e.g. "Phase 5.2" or YAML "phase_id: 5.2"), role, notes.
    # YAML detection: presence of `phase_log:` at column 0 → split on YAML list-item prefix.
    # Markdown: split on heading delimiters (##/###/####).
    param([string]$PipelineText)

    $entries = @()
    if (-not $PipelineText) { return ,$entries }

    # Detect YAML format
    $isYaml = $PipelineText -match '(?m)^\s*phase_log\s*:'

    if ($isYaml) {
        # Split YAML phase_log entries on the list-item prefix at any indent
        # (an entry starts with "- phase_id:" or "- role:").
        $body = $PipelineText
        # Isolate the phase_log: ... section (everything from `phase_log:` to next top-level key or EOF)
        $startMatch = [regex]::Match($body, '(?m)^phase_log\s*:\s*(?:#[^\n]*)?\s*\r?\n')
        if ($startMatch.Success) {
            $sectionStart = $startMatch.Index + $startMatch.Length
            # Find next top-level key (starts at column 0, not a list-item)
            $rest = $body.Substring($sectionStart)
            $endMatch = [regex]::Match($rest, '(?m)^[A-Za-z_][A-Za-z0-9_]*\s*:')
            $section = if ($endMatch.Success) { $rest.Substring(0, $endMatch.Index) } else { $rest }
            # Split into per-entry chunks
            $chunks = [regex]::Split($section, '(?m)^\s*-\s')
            foreach ($chunk in $chunks) {
                if ([string]::IsNullOrWhiteSpace($chunk)) { continue }
                if ($chunk -notmatch '(?im)\bintended_handle\b') { continue }
                if ($chunk -notmatch '(?im)\bactual_model_id\b') { continue }
                if ($chunk -notmatch '(?im)\bdispatch_status\b') { continue }

                $phaseId = $null
                if ($chunk -match "(?im)^\s*phase_id\s*[:=]\s*['""]?([^'""\r\n]+?)['""]?\s*$") { $phaseId = $matches[1].Trim() }
                $role = $null
                if ($chunk -match "(?im)^\s*role\s*[:=]\s*([^\r\n]+)") { $role = $matches[1].Trim() }

                $extract = {
                    param($field)
                    if ($chunk -match "(?im)^\s*$field\s*[:=]\s*['""]?([^'""\r\n]+?)['""]?\s*$") { return $matches[1].Trim() }
                    return $null
                }

                $entries += [pscustomobject]@{
                    PhaseId        = $phaseId
                    Role           = $role
                    IntendedHandle = & $extract 'intended_handle'
                    ActualModelId  = & $extract 'actual_model_id'
                    ActualProvider = & $extract 'actual_provider'
                    ActualFamily   = (& $extract 'actual_family')?.ToLowerInvariant()
                    DispatchStatus = & $extract 'dispatch_status'
                    Notes          = & $extract 'notes'
                }
            }
            return ,$entries
        }
    }

    # Legacy markdown path — split on headings (##, ###, ####) AND on horizontal rules.
    $chunks = [regex]::Split($PipelineText, '(?m)^(?:#{2,4}\s+|---\s*$)')
    foreach ($chunk in $chunks) {
        if ([string]::IsNullOrWhiteSpace($chunk)) { continue }
        if ($chunk -notmatch '(?im)\bintended_handle\b') { continue }
        if ($chunk -notmatch '(?im)\bactual_model_id\b') { continue }
        if ($chunk -notmatch '(?im)\bdispatch_status\b') { continue }

        $phaseId = $null
        if ($chunk -match '(?im)\bPhase\s+(\d+(?:\.\d+)?[a-z]?)\b') { $phaseId = $matches[1] }
        elseif ($chunk -match '(?im)^\s*phase\s*[:=]\s*([0-9.a-z]+)') { $phaseId = $matches[1] }

        $role = $null
        if ($chunk -match '(?im)^\s*role\s*[:=]\s*([^\r\n]+)') { $role = $matches[1].Trim() }
        elseif ($chunk -match '(?im)\b(Lead|Orchestrator|Builder\s*A|Builder\s*B|Critic|Fact-?checker|Auditor|Reviewer|Stress-test)\b') { $role = $matches[1].Trim() }

        $get = {
            param($field)
            if ($chunk -match "(?im)^\s*[-*]?\s*$field\s*[:=]\s*([^\r\n]+)") { return $matches[1].Trim().TrimEnd(',') }
            return $null
        }

        $entries += [pscustomobject]@{
            PhaseId        = $phaseId
            Role           = $role
            IntendedHandle = & $get 'intended_handle'
            ActualModelId  = & $get 'actual_model_id'
            ActualProvider = & $get 'actual_provider'
            ActualFamily   = (& $get 'actual_family')?.ToLowerInvariant()
            DispatchStatus = & $get 'dispatch_status'
            Notes          = & $get 'notes'
        }
    }
    return ,$entries
}

function Test-Rule19FamilySeparation {
    # Evaluates Rule 19 (Model-Family Separation) against per-phase ACTUALS (not intentions).
    # Returns an aggregate pscustomobject with overall_status, pair_results, acknowledged_opt_outs,
    # has_silent_violation, has_ack_opt_out, has_insufficient_data, within_phase_findings.
    #
    # Canonical verification pairs are sourced from 01-shared-axioms.md Rule 19:
    #   - Phase 1.2 critique ≠ Phase 1.1 builder research
    #   - Phase 5.4 fact-check ≠ Phase 5.2 build
    #   - Phase 6.4 fact-check ≠ Phase 5.2 build
    #   - Phase 7.0 audit ≠ Phase 6.4 AND ≠ Phase 5.2
    #   - Phase 8.0 stress-test memo fact-check ≠ Phase 6.4
    # Within-phase: Builder A actual_family ≠ Builder B actual_family (the standard preset
    # enforces this at assignment time; the scorecard verifies actual dispatch followed
    # through). Also: Lead actual_model_id ≠ both Builder A AND Builder B actual_model_id
    # (the v3.1.6 anti-pattern detector — Lead-acted-as-both-Builders shows up as Lead model
    # identical to both Builder models).
    param([array]$Entries)

    $emptyResult = [pscustomobject]@{
        OverallStatus       = 'insufficient-data'
        PairResults         = @()
        WithinPhaseFindings = @()
        AcknowledgedOptOuts = @()
        HasSilentViolation  = $false
        HasAckOptOut        = $false
        HasInsufficientData = $true
        EntryCount          = 0
    }
    if (-not $Entries -or $Entries.Count -eq 0) { return $emptyResult }

    $pairs = @(
        @{ Verifier='1.2'; Producer='1.1'; Label='Phase 1.2 critique vs Phase 1.1 builder research' },
        @{ Verifier='5.4'; Producer='5.2'; Label='Phase 5.4 fact-check vs Phase 5.2 build' },
        @{ Verifier='6.4'; Producer='5.2'; Label='Phase 6.4 fact-check vs Phase 5.2 build' },
        @{ Verifier='7.0'; Producer='5.2'; Label='Phase 7.0 audit vs Phase 5.2 build' },
        @{ Verifier='7.0'; Producer='6.4'; Label='Phase 7.0 audit vs Phase 6.4 fact-check' },
        @{ Verifier='8.0'; Producer='6.4'; Label='Phase 8.0 stress-test memo fact-check vs Phase 6.4 fact-check' }
    )

    # Group entries by phase id; if multiple roles per phase, prefer the verifier/producer role
    # natural to that phase (best-effort — when ambiguous, surface in detail string).
    $byPhase = @{}
    foreach ($e in $Entries) {
        if (-not $e.PhaseId) { continue }
        if (-not $byPhase.ContainsKey($e.PhaseId)) { $byPhase[$e.PhaseId] = @() }
        $byPhase[$e.PhaseId] += $e
    }

    $pairResults = @()
    $ackOptOuts  = @()
    foreach ($pair in $pairs) {
        $vEntries = if ($byPhase.ContainsKey($pair.Verifier)) { @($byPhase[$pair.Verifier]) } else { @() }
        $pEntries = if ($byPhase.ContainsKey($pair.Producer)) { @($byPhase[$pair.Producer]) } else { @() }
        if ($vEntries.Count -eq 0 -or $pEntries.Count -eq 0) {
            $pairResults += [pscustomobject]@{
                Pair = $pair.Label; Verdict='INSUFFICIENT_DATA';
                Detail='One or both phases missing Rule 20 actuals in pipeline_state.md.';
                VerifierFamily=$null; ProducerFamily=$null;
                VerifierStatus=$null; ProducerStatus=$null
            }
            continue
        }
        # For verifier phases, use the role most likely to be doing the verification;
        # for producer phases, use any builder entry. If multiple families on either side,
        # collapse to a unique set and require at least one cross-family pairing.
        $vFamilies = @($vEntries | ForEach-Object { $_.ActualFamily } | Where-Object { $_ } | Select-Object -Unique)
        $pFamilies = @($pEntries | ForEach-Object { $_.ActualFamily } | Where-Object { $_ } | Select-Object -Unique)
        $vStatus = @($vEntries | ForEach-Object { $_.DispatchStatus } | Where-Object { $_ } | Select-Object -Unique)
        $pStatus = @($pEntries | ForEach-Object { $_.DispatchStatus } | Where-Object { $_ } | Select-Object -Unique)

        if ($vFamilies.Count -eq 0 -or $pFamilies.Count -eq 0) {
            $pairResults += [pscustomobject]@{
                Pair=$pair.Label; Verdict='INSUFFICIENT_DATA';
                Detail='Actual family missing (model not present in registry, or registry not consulted).';
                VerifierFamily=($vFamilies -join ','); ProducerFamily=($pFamilies -join ',');
                VerifierStatus=($vStatus -join ','); ProducerStatus=($pStatus -join ',')
            }
            continue
        }

        $isOptOut = ($vStatus -contains 'failed-then-acknowledged-opt-out') -or ($pStatus -contains 'failed-then-acknowledged-opt-out')
        # ENFORCED if every verifier family differs from every producer family (no overlap).
        # SILENTLY_VIOLATED if any verifier family equals any producer family and not opt-out-tagged.
        # ACKNOWLEDGED_OPT_OUT if same family present but dispatch_status flags the opt-out.
        $overlap = @($vFamilies | Where-Object { $pFamilies -contains $_ })
        if ($overlap.Count -eq 0) {
            $verdict = 'ENFORCED'
        } elseif ($isOptOut) {
            $verdict = 'ACKNOWLEDGED_OPT_OUT'
            $ackOptOuts += $pair.Label
        } else {
            $verdict = 'SILENTLY_VIOLATED'
        }
        $pairResults += [pscustomobject]@{
            Pair=$pair.Label; Verdict=$verdict;
            VerifierFamily=($vFamilies -join ','); ProducerFamily=($pFamilies -join ',');
            VerifierStatus=($vStatus -join ','); ProducerStatus=($pStatus -join ',');
            Detail=$null
        }
    }

    # Within-phase distinctness checks (Builder A vs Builder B; Lead-as-both-builders detector).
    $withinFindings = @()
    foreach ($phaseKey in $byPhase.Keys) {
        $phaseEntries = @($byPhase[$phaseKey])
        $builderA = $phaseEntries | Where-Object { $_.Role -match '(?i)Builder\s*A' } | Select-Object -First 1
        $builderB = $phaseEntries | Where-Object { $_.Role -match '(?i)Builder\s*B' } | Select-Object -First 1
        $lead     = $phaseEntries | Where-Object { $_.Role -match '(?i)Lead|Orchestrator' } | Select-Object -First 1

        if ($builderA -and $builderB -and $builderA.ActualFamily -and $builderB.ActualFamily) {
            $isOptOut = ($builderA.DispatchStatus -eq 'failed-then-acknowledged-opt-out' -or $builderB.DispatchStatus -eq 'failed-then-acknowledged-opt-out')
            if ($builderA.ActualFamily -eq $builderB.ActualFamily) {
                $verdict = if ($isOptOut) { 'ACKNOWLEDGED_OPT_OUT' } else { 'SILENTLY_VIOLATED' }
                $withinFindings += [pscustomobject]@{
                    Phase=$phaseKey; Check='Builder A vs Builder B family distinctness'; Verdict=$verdict;
                    Detail="Both builders dispatched to family '$($builderA.ActualFamily)'. Standard preset requires cross-family builders."
                }
                if ($verdict -eq 'ACKNOWLEDGED_OPT_OUT') { $ackOptOuts += "Phase $phaseKey Builder A/B same-family" }
            }
        }

        # v3.1.6 anti-pattern: Lead dispatched as one or both Builders (silent fallback).
        if ($lead -and $builderA -and $lead.ActualModelId -and $builderA.ActualModelId -and $lead.ActualModelId -eq $builderA.ActualModelId) {
            $isOptOut = ($lead.DispatchStatus -eq 'failed-then-acknowledged-opt-out' -or $builderA.DispatchStatus -eq 'failed-then-acknowledged-opt-out')
            $verdict = if ($isOptOut) { 'ACKNOWLEDGED_OPT_OUT' } else { 'SILENTLY_VIOLATED' }
            $withinFindings += [pscustomobject]@{
                Phase=$phaseKey; Check='Lead-acted-as-Builder-A detector (v3.1.6 anti-pattern)'; Verdict=$verdict;
                Detail="Lead actual_model_id ('$($lead.ActualModelId)') identical to Builder A's. This is the silent-fallback pattern v3.1.6's DISPATCH-FAILURE CONTRACT forbids."
            }
        }
        if ($lead -and $builderB -and $lead.ActualModelId -and $builderB.ActualModelId -and $lead.ActualModelId -eq $builderB.ActualModelId) {
            $isOptOut = ($lead.DispatchStatus -eq 'failed-then-acknowledged-opt-out' -or $builderB.DispatchStatus -eq 'failed-then-acknowledged-opt-out')
            $verdict = if ($isOptOut) { 'ACKNOWLEDGED_OPT_OUT' } else { 'SILENTLY_VIOLATED' }
            $withinFindings += [pscustomobject]@{
                Phase=$phaseKey; Check='Lead-acted-as-Builder-B detector (v3.1.6 anti-pattern)'; Verdict=$verdict;
                Detail="Lead actual_model_id ('$($lead.ActualModelId)') identical to Builder B's. This is the silent-fallback pattern v3.1.6's DISPATCH-FAILURE CONTRACT forbids."
            }
        }
    }

    $allResults = @($pairResults) + @($withinFindings)
    $hasSilent = @($allResults | Where-Object { $_.Verdict -eq 'SILENTLY_VIOLATED' }).Count -gt 0
    $hasAck    = @($allResults | Where-Object { $_.Verdict -eq 'ACKNOWLEDGED_OPT_OUT' }).Count -gt 0
    $hasInsuf  = @($pairResults | Where-Object { $_.Verdict -eq 'INSUFFICIENT_DATA' }).Count -gt 0
    $allEnforced = (@($pairResults | Where-Object { $_.Verdict -eq 'ENFORCED' }).Count -eq $pairResults.Count) -and (-not $hasSilent) -and (-not $hasAck)

    $overallStatus = if ($hasSilent) { 'silently-violated' }
                     elseif ($hasInsuf -and -not $hasAck -and -not $allEnforced) { 'insufficient-data' }
                     elseif ($hasAck) { 'enforced-with-acknowledged-opt-outs' }
                     elseif ($allEnforced) { 'enforced' }
                     else { 'insufficient-data' }

    return [pscustomobject]@{
        OverallStatus       = $overallStatus
        PairResults         = $pairResults
        WithinPhaseFindings = $withinFindings
        AcknowledgedOptOuts = @($ackOptOuts | Select-Object -Unique)
        HasSilentViolation  = $hasSilent
        HasAckOptOut        = $hasAck
        HasInsufficientData = $hasInsuf
        EntryCount          = $Entries.Count
    }
}

if (-not (Test-Path -LiteralPath $KBRoot)) { throw "KBRoot not found: $KBRoot" }
$KBRoot = (Resolve-Path -LiteralPath $KBRoot).Path
$auditDir = Join-Path $KBRoot 'audit'
if (-not (Test-Path -LiteralPath $auditDir)) { New-Item -ItemType Directory -Path $auditDir -Force | Out-Null }

$scorecardPath = Join-Path $auditDir 'kb-quality-scorecard.md'
$jsonPath = Join-Path $auditDir 'kb-quality.json'
$historyPath = Join-Path $auditDir 'kb-quality-history.json'

$expectedStructure = @('full','authority','practice','sources','AGENTS.md','index.md','table-of-authorities.md')
$structure = @($expectedStructure | ForEach-Object { Test-Artifact $_ })
$missingStructure = @($structure | Where-Object { -not $_.Exists })

$artifactRelatives = @(
    'sources\pipeline_state.md',
    'sources\new_claims_manifest.md',
    'sources\unresolved_unverified_manifest.md',
    'sources\volatile_tag_manifest.md',
    'sources\post_assembly_factcheck.md',
    'sources\quality_tier_audit.md',
    'sources\audit_report.md',
    'sources\register_lint_report.md',
    'sources\authority_view_extraction.md',
    'sources\filename_validation.md',
    'table-of-authorities.md'
)
$artifactStatus = @($artifactRelatives | ForEach-Object { Test-Artifact $_ })
$factcheckFiles = @(Get-ChildItem -LiteralPath (Join-Path $KBRoot 'sources') -Filter 'factcheck_*.md' -File -ErrorAction SilentlyContinue)
$stressFiles = @(Get-ChildItem -LiteralPath (Join-Path $KBRoot 'sources') -Filter 'stress_test_report_*.md' -File -ErrorAction SilentlyContinue)
$missingArtifacts = @($artifactStatus | Where-Object { -not $_.Exists } | ForEach-Object { $_.Relative })
if ($factcheckFiles.Count -eq 0) { $missingArtifacts += 'sources\factcheck_*.md' }
if ($stressFiles.Count -eq 0) { $missingArtifacts += 'sources\stress_test_report_*.md' }

$pipelineTextYaml = Get-TextOrNull (Join-Path $KBRoot 'sources\pipeline_state.yaml')
$pipelineText = if ($pipelineTextYaml) { $pipelineTextYaml } else { Get-TextOrNull (Join-Path $KBRoot 'sources\pipeline_state.md') }
$phaseProvenance = Get-PhaseProvenance -PipelineText $pipelineText
$rule19 = Test-Rule19FamilySeparation -Entries $phaseProvenance
$toaText = Get-TextOrNull (Join-Path $KBRoot 'table-of-authorities.md')

# v3.1.14 — Citation-engine fact-check (Phase 5.6) — read structured JSON for the new dimension
$citationEngineJsonPath = Join-Path $KBRoot 'sources\factcheck_citation_engine.json'
$citationEngine = $null
if (Test-Path -LiteralPath $citationEngineJsonPath -PathType Leaf) {
    try { $citationEngine = Get-Content -LiteralPath $citationEngineJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $citationEngine = $null }
}

# v3.1.15 — Test-set evaluation (Phase 7.0 sub-step) — read structured JSON for the new dimension + PASS gating
$testSetJsonPath = Join-Path $KBRoot 'audit\test-set-results.json'
$testSet = $null
if (Test-Path -LiteralPath $testSetJsonPath -PathType Leaf) {
    try { $testSet = Get-Content -LiteralPath $testSetJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $testSet = $null }
}
$registerText = Get-TextOrNull (Join-Path $KBRoot 'sources\register_lint_report.md')
$authorityText = Get-TextOrNull (Join-Path $KBRoot 'sources\authority_view_extraction.md')
$filenameText = Get-TextOrNull (Join-Path $KBRoot 'sources\filename_validation.md')
$volatileText = Get-TextOrNull (Join-Path $KBRoot 'sources\volatile_tag_manifest.md')
$postAssemblyText = Get-TextOrNull (Join-Path $KBRoot 'sources\post_assembly_factcheck.md')
$qualityTierText = Get-TextOrNull (Join-Path $KBRoot 'sources\quality_tier_audit.md')
$auditText = Get-TextOrNull (Join-Path $KBRoot 'sources\audit_report.md')
$operativeText = Get-TextOrNull (Join-Path $KBRoot 'sources\factcheck_operative_claims.md')

$toaRows = Get-RegexCount $toaText '(?m)^\s*\|.*\|\s*$'
$primaryHits = Get-RegexCount $toaText '\bprimary\b|official|statute|regulation|standard|guidance'
$factcheckPass = 0
$factcheckFail = 0
foreach ($f in $factcheckFiles) {
    $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $factcheckPass += Get-RegexCount $t '\bPASS\b|\bCLEAN\b'
    $factcheckFail += Get-RegexCount $t '\bFAIL\b|\bBLOCK\b|\bCRITICAL\b|\bNEEDS-VERIFICATION\b'
}
$citationScore = if ($toaText) {
    $densityScore = [math]::Min(60, $toaRows * 3)
    $primaryRate = if ($toaRows -gt 0) { [math]::Min(40, ($primaryHits / [math]::Max(1,$toaRows)) * 100) } else { 0 }
    Clamp-Score ($densityScore + $primaryRate - ($factcheckFail * 3))
} else { 0 }

$registerFindings = if ($registerText -and $registerText -match 'Paragraphs flagged:\*\*\s*(\d+)') { [int]$matches[1] } else { Get-RegexCount $registerText '^\|\s*\d+\s*\|' }
$inlineBlocks = Get-RegexCount $authorityText 'inline-position register tags|VERDICT:\s*\*\*BLOCK'
$authorityReportsPresent = if ($authorityText) { 1 } else { 0 }
$practicePresent = if (Test-Path -LiteralPath (Join-Path $KBRoot 'practice')) { 1 } else { 0 }
$registerScore = Clamp-Score (100 - ($registerFindings * 4) - ($inlineBlocks * 20) - (20 * (1 - $authorityReportsPresent)) - (10 * (1 - $practicePresent)))

$crossRefCount = Get-RegexCount ($operativeText + "`n" + $filenameText) 'cross-reference|canonical|restatement|filename|link'
$crossRefFails = Get-RegexCount ($operativeText + "`n" + $filenameText) 'paraphrase-drop|broken|unresolved|FAIL|BLOCK|CRITICAL'
$crossRefScore = if ($operativeText -or $filenameText) { Clamp-Score (90 + [math]::Min(10,$crossRefCount) - ($crossRefFails * 8)) } else { 0 }

$qualifierRows = Get-RegexCount (Get-TextOrNull (Join-Path $KBRoot 'qualifier-registry.md')) '(?m)^\s*\|'
$qualifierDrops = Get-RegexCount ($operativeText + "`n" + $auditText) 'qualifier.*drop|paraphrase-drop|dropped qualifier|FAIL|CRITICAL'
$qualifierScore = if ($operativeText -or $qualifierRows -gt 0) { Clamp-Score (95 - ($qualifierDrops * 10) + [math]::Min(5,$qualifierRows)) } else { 0 }

$volatileTags = Get-RegexCount $volatileText '\[VOLATILE:'
$volatileGaps = Get-RegexCount $volatileText 'missing|untagged|NEEDS-VERIFICATION|FAIL|BLOCK'
$volatileScore = if ($volatileText) { Clamp-Score (100 - ($volatileGaps * 12) + [math]::Min(5,$volatileTags)) } else { 0 }

$stressPass = 0
$stressFail = 0
foreach ($f in $stressFiles) {
    $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $stressPass += Get-RegexCount $t '\bPASS\b|\bCLEAN\b|100%'
    $stressFail += Get-RegexCount $t '\bFAIL\b|\bLEAKAGE\b|\bBLOCK\b|\bCRITICAL\b'
}
$stressScore = if ($stressFiles.Count -gt 0) {
    $denom = [math]::Max(1, $stressPass + $stressFail)
    Clamp-Score (($stressPass / $denom) * 100)
} else { 0 }

$fullFiles = @(Get-ChildItem -LiteralPath (Join-Path $KBRoot 'full') -Filter '*.md' -File -ErrorAction SilentlyContinue)
$authorityFiles = @(Get-ChildItem -LiteralPath (Join-Path $KBRoot 'authority') -Filter '*.md' -File -ErrorAction SilentlyContinue)
$practiceFiles = @(Get-ChildItem -LiteralPath (Join-Path $KBRoot 'practice') -Filter '*.md' -File -ErrorAction SilentlyContinue)
$structurePresentRatio = (($structure.Count - $missingStructure.Count) / [math]::Max(1,$structure.Count)) * 100
$filePeerScore = if ($fullFiles.Count -gt 0) { ([math]::Min($authorityFiles.Count,$fullFiles.Count) + [math]::Min($practiceFiles.Count,$fullFiles.Count)) / ($fullFiles.Count * 2) * 100 } else { 0 }
$tierFailures = Get-RegexCount ($qualityTierText + "`n" + $filenameText) '\bFAIL\b|\bBLOCK\b|too small|missing'
$structuralScore = Clamp-Score ((0.6 * $structurePresentRatio) + (0.4 * $filePeerScore) - ($tierFailures * 5))

$dimensions = @(
    (New-Dimension -Name 'Citation density & primary-source rate' -Score $citationScore -Threshold 80 -Method 'Counts table-of-authorities rows, primary-source markers, and Phase 5 fact-check failures.' -Data @{ citations=$toaRows; primary_markers=$primaryHits; factcheck_failures=$factcheckFail })
    (New-Dimension -Name 'Register-tag coverage & extraction integrity' -Score $registerScore -Threshold 85 -Method 'Uses register-lint findings, authority extraction report, inline-tag blocks, and practice/ presence.' -Data @{ register_findings=$registerFindings; inline_blocks=$inlineBlocks; authority_report_present=[bool]$authorityText; practice_present=[bool]$practicePresent })
    (New-Dimension -Name 'Cross-reference fidelity' -Score $crossRefScore -Threshold 90 -Method 'Uses operative-claim fact-check and filename validation artifacts for broken/drifting cross-reference signals.' -Data @{ cross_reference_markers=$crossRefCount; failures=$crossRefFails })
    (New-Dimension -Name 'Qualifier preservation' -Score $qualifierScore -Threshold 80 -Method 'Uses operative-claim audit, audit report, and qualifier-registry coverage where present.' -Data @{ qualifier_registry_rows=$qualifierRows; qualifier_drop_findings=$qualifierDrops })
    (New-Dimension -Name 'Volatile-tag coverage' -Score $volatileScore -Threshold 95 -Method 'Uses volatile_tag_manifest.md for VOLATILE tags and untagged/gap findings.' -Data @{ volatile_tags=$volatileTags; volatile_gaps=$volatileGaps })
    (New-Dimension -Name 'Stress-test pass rate' -Score $stressScore -Threshold 100 -Method 'Uses stress_test_report_*.md PASS/CLEAN vs FAIL/LEAKAGE/BLOCK markers.' -Data @{ stress_reports=$stressFiles.Count; pass_markers=$stressPass; fail_markers=$stressFail })
    (New-Dimension -Name 'Structural & size compliance' -Score $structuralScore -Threshold 90 -Method 'Checks expected directories/root files, full-authority-practice peer coverage, and tier/filename failure markers.' -Data @{ missing_structure=@($missingStructure.Relative); full_files=$fullFiles.Count; authority_files=$authorityFiles.Count; practice_files=$practiceFiles.Count; tier_failures=$tierFailures })
    $(
        # v3.1.14 — Citation-engine verification rate dimension
        $citeVerified = 0; $citeFallback = 0; $citeNotFound = 0; $citeWrongText = 0; $citeWrongCite = 0; $citeErrored = 0; $citeTotal = 0; $citeMode = 'absent'
        if ($citationEngine) {
            $citeTotal = if ($citationEngine.counts -and $citationEngine.counts.PSObject.Properties.Name -contains 'total') { [int]$citationEngine.counts.total } else { [int]($citationEngine.results | Measure-Object).Count }
            if ($citationEngine.counts) {
                if ($citationEngine.counts.PSObject.Properties.Name -contains 'VERIFIED') { $citeVerified = [int]$citationEngine.counts.VERIFIED }
                if ($citationEngine.counts.PSObject.Properties.Name -contains 'VERIFIED_BY_PRESENCE') { $citeFallback = [int]$citationEngine.counts.VERIFIED_BY_PRESENCE }
                if ($citationEngine.counts.PSObject.Properties.Name -contains 'NOT_FOUND') { $citeNotFound = [int]$citationEngine.counts.NOT_FOUND }
                if ($citationEngine.counts.PSObject.Properties.Name -contains 'WRONG_TEXT') { $citeWrongText = [int]$citationEngine.counts.WRONG_TEXT }
                if ($citationEngine.counts.PSObject.Properties.Name -contains 'SUPPORTED_BUT_WRONG_CITE') { $citeWrongCite = [int]$citationEngine.counts.SUPPORTED_BUT_WRONG_CITE }
                if ($citationEngine.counts.PSObject.Properties.Name -contains 'ERRORED') { $citeErrored = [int]$citationEngine.counts.ERRORED }
            }
            if ($citationEngine.mode) { $citeMode = [string]$citationEngine.mode }
            $denom = [math]::Max(1, $citeTotal - $citeErrored)
            # VERIFIED counts at full weight; VERIFIED_BY_PRESENCE at 70% (no claim-text support check)
            $citeScore = Clamp-Score ((($citeVerified + 0.7 * $citeFallback) / $denom) * 100)
        } else {
            $citeScore = 0
        }
        New-Dimension -Name 'Citation-engine verification rate' -Score $citeScore -Threshold 80 -Method "v3.1.14 — counts (VERIFIED + 0.7 * VERIFIED_BY_PRESENCE) / (total - ERRORED) from sources/factcheck_citation_engine.json. Score 0 when Phase 5.6 not run." -Data @{ mode=$citeMode; total=$citeTotal; verified=$citeVerified; verified_by_presence=$citeFallback; not_found=$citeNotFound; wrong_text=$citeWrongText; supported_but_wrong_cite=$citeWrongCite; errored=$citeErrored }
    )
    $(
        # v3.1.15 — Test-set passage rate dimension
        $tsTotal = 0; $tsPassed = 0; $tsFailed = 0; $tsErrored = 0; $tsNa = 0; $tsRate = 0.0
        $tsThresholdRate = 0.80; $tsThresholdMet = $false; $tsBlockerFailed = $false; $tsMode = 'absent'
        if ($testSet) {
            $tsTotal = [int]($testSet.total); $tsPassed = [int]($testSet.passed); $tsFailed = [int]($testSet.failed)
            $tsErrored = [int]($testSet.errored); $tsNa = [int]($testSet.na)
            $tsRate = [double]($testSet.passage_rate)
            $tsThresholdRate = [double]($testSet.threshold_passage_rate)
            $tsThresholdMet = [bool]($testSet.threshold_met)
            $tsBlockerFailed = [bool]($testSet.blocker_failed)
            if ($testSet.mode) { $tsMode = [string]$testSet.mode }
            # Score: passage_rate as percentage (0..100). Threshold derived from test-set declaration.
            $tsScore = Clamp-Score ($tsRate * 100)
        } else {
            $tsScore = 0
        }
        New-Dimension -Name 'Test-set passage rate' -Score $tsScore -Threshold ([int]($tsThresholdRate * 100)) -Method "v3.1.15 — passage_rate * 100 from audit/test-set-results.json. Test-set is operator-curated per-KB at audit/test-set.yaml. Score 0 when not run." -Data @{ mode=$tsMode; total=$tsTotal; passed=$tsPassed; failed=$tsFailed; errored=$tsErrored; na=$tsNa; passage_rate=$tsRate; threshold_passage_rate=$tsThresholdRate; threshold_met=$tsThresholdMet; blocker_failed=$tsBlockerFailed }
    )
)

$weights = Get-Weights -Path $WeightsPath
$composite = 0.0
foreach ($d in $dimensions) { $composite += ([double]$d.Score * [double]$weights[$d.Name]) }
$qualityIndex = Clamp-Score $composite
$critical = (Get-RegexCount ($auditText + "`n" + $postAssemblyText + "`n" + $qualityTierText) '\bCRITICAL\b|\bBLOCKER\b') -gt 0
$minBelowThreshold = @($dimensions | ForEach-Object { $_.Threshold - $_.Score } | Measure-Object -Maximum).Maximum

if ($missingArtifacts.Count -gt 0 -or $missingStructure.Count -gt 0) {
    $overallVerdict = 'BUILD-INCOMPLETE'
} elseif ($qualityIndex -ge 90 -and @($dimensions | Where-Object { $_.Score -lt $_.Threshold }).Count -eq 0 -and $stressScore -eq 100) {
    $overallVerdict = 'PASS'
} elseif ($qualityIndex -ge 80 -and $minBelowThreshold -le 10 -and $stressScore -eq 100) {
    $overallVerdict = 'PASS-WITH-CAVEATS'
} elseif ($qualityIndex -ge 70 -and $stressScore -ge 80 -and -not $critical) {
    $overallVerdict = 'CONDITIONAL'
} else {
    $overallVerdict = 'FAIL'
}

# Rule 19 (Model-Family Separation) verdict adjustment per audit-templates/kb-quality-dimensions.yaml
# § family_separation_exception_handling and 01-shared-axioms.md Rule 19/20:
#   - silently-violated: downgrade to FAIL (verification independence lost without operator acknowledgment)
#   - insufficient-data: cap at PASS-WITH-CAVEATS (cannot confirm Rule 19 was followed against actuals)
#   - enforced-with-acknowledged-opt-outs: tag affected dimensions; do NOT auto-downgrade composite
#   - enforced: no effect
$tagged_dimensions = @()
$rule19_methodology_note = $null
switch ($rule19.OverallStatus) {
    'silently-violated' {
        $overallVerdict = 'FAIL'
        $rule19_methodology_note = "Rule 19 (Model-Family Separation) was silently violated — same-family verification occurred without operator acknowledgment per Rule 20 actuals in pipeline_state.md. Composite verdict forced to FAIL."
    }
    'insufficient-data' {
        if ($overallVerdict -eq 'PASS') { $overallVerdict = 'PASS-WITH-CAVEATS' }
        $rule19_methodology_note = "Rule 20 actuals missing or incomplete in pipeline_state.md — Rule 19 family-separation cannot be verified against actuals. Composite verdict capped at PASS-WITH-CAVEATS."
    }
    'enforced-with-acknowledged-opt-outs' {
        $tagged_dimensions = @('Cross-reference fidelity','Qualifier preservation','Citation density & primary-source rate')
        foreach ($d in $dimensions) {
            if ($tagged_dimensions -contains $d.Name) { $d.FamilySeparationTag = 'verification-independence-degraded' }
        }
        $rule19_methodology_note = 'Build had an acknowledged Rule 19 (Model-Family Separation) opt-out per pipeline_state.md actuals. Affected dimension scores are tagged "verification-independence-degraded". Composite verdict is NOT auto-downgraded per audit-templates/kb-quality-dimensions.yaml policy; reviewer should weigh the discipline tradeoff.'
    }
    'enforced' {
        $rule19_methodology_note = 'Rule 19 (Model-Family Separation) enforced against per-phase actuals — all canonical verification pairs used cross-family models.'
    }
}

$modelAssignment = @{}
if ($pipelineText) {
    $modelAssignment['raw_excerpt'] = (([regex]::Match($pipelineText, '(?is)model_assignment\s*:?\s*(.{0,2000})')).Value -replace "`r?`n", "`n").Trim()
}

# v3.1.15 — Test-set PASS gating: if test-set is present and threshold NOT met, force composite to FAIL.
# Blocker-failed (any blocker-severity question failed) also forces FAIL regardless of overall passage rate.
$testSetGateNote = $null
if ($testSet) {
    if (-not [bool]$testSet.threshold_met) {
        $overallVerdict = if ($overallVerdict -in @('FAIL','BUILD-INCOMPLETE')) { $overallVerdict } else { 'FAIL' }
        $testSetGateNote = ("Test-set passage rate {0:P1} below threshold {1:P0}. Composite verdict forced to FAIL per v3.1.15 PASS gating." -f $testSet.passage_rate, $testSet.threshold_passage_rate)
    }
    if ([bool]$testSet.blocker_failed) {
        $overallVerdict = 'FAIL'
        if ($testSetGateNote) { $testSetGateNote += " ALSO: blocker-severity question failed." }
        else { $testSetGateNote = "Blocker-severity test-set question failed. Composite verdict forced to FAIL per v3.1.15 PASS gating." }
    }
}

$scoreObject = [ordered]@{
    framework_version = 'v3.1.15'
    kb_root = $KBRoot
    generated_at = (Get-Date).ToString('o')
    verdict = $overallVerdict
    kb_quality_index = $qualityIndex
    dimensions = @($dimensions | ForEach-Object { [ordered]@{ name=$_.Name; score=$_.Score; threshold=$_.Threshold; verdict=$_.Verdict; method=$_.Method; data=$_.Data; family_separation_tag=$_.FamilySeparationTag } })
    weights = $weights
    model_assignment = $modelAssignment
    model_provenance = [ordered]@{
        rule20_entry_count = $phaseProvenance.Count
        per_phase_actuals = @($phaseProvenance | ForEach-Object { [ordered]@{ phase_id=$_.PhaseId; role=$_.Role; intended_handle=$_.IntendedHandle; actual_model_id=$_.ActualModelId; actual_provider=$_.ActualProvider; actual_family=$_.ActualFamily; dispatch_status=$_.DispatchStatus; notes=$_.Notes } })
        rule19_family_separation = [ordered]@{
            overall_status = $rule19.OverallStatus
            pair_results = @($rule19.PairResults | ForEach-Object { [ordered]@{ pair=$_.Pair; verdict=$_.Verdict; verifier_family=$_.VerifierFamily; producer_family=$_.ProducerFamily; verifier_status=$_.VerifierStatus; producer_status=$_.ProducerStatus; detail=$_.Detail } })
            within_phase_findings = @($rule19.WithinPhaseFindings | ForEach-Object { [ordered]@{ phase=$_.Phase; check=$_.Check; verdict=$_.Verdict; detail=$_.Detail } })
            acknowledged_opt_outs = $rule19.AcknowledgedOptOuts
            has_silent_violation = $rule19.HasSilentViolation
            tagged_dimensions = $tagged_dimensions
            methodology_note = $rule19_methodology_note
        }
    }
    missing_artifacts = @($missingArtifacts | Select-Object -Unique)
    missing_structure = @($missingStructure.Relative)
}

$scoreObject | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$history = @()
if (Test-Path -LiteralPath $historyPath) {
    try { $history = @(Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $history = @() }
}
$history += [pscustomobject]$scoreObject
$history | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $historyPath -Encoding UTF8

$md = New-Object System.Collections.Generic.List[string]
$kbName = Split-Path -Leaf $KBRoot
$md.Add("# KB Quality Scorecard — $kbName") | Out-Null
$md.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Pipeline version: v3.0") | Out-Null
$md.Add('') | Out-Null
$md.Add('## OVERALL VERDICT') | Out-Null
$md.Add('') | Out-Null
$md.Add("**$overallVerdict**") | Out-Null
$md.Add('') | Out-Null
if ($overallVerdict -eq 'BUILD-INCOMPLETE') {
    $md.Add('This is a partial scorecard. One or more expected v3 build artifacts are missing, so scores reflect currently available evidence only.') | Out-Null
} else {
    $md.Add("Composite KB Quality Index: **$qualityIndex / 100**.") | Out-Null
}
$md.Add('') | Out-Null
$md.Add('## HEADLINE SCORES') | Out-Null
$md.Add('') | Out-Null
$md.Add('| Dimension | Score | Threshold | Verdict |') | Out-Null
$md.Add('|---|---:|---:|---|') | Out-Null
foreach ($d in $dimensions) {
    $tagSuffix = if ($d.FamilySeparationTag) { " *(tag: $($d.FamilySeparationTag))*" } else { '' }
    $md.Add("| $($d.Name) | $($d.Score) | ≥$($d.Threshold) | $($d.Verdict)$tagSuffix |") | Out-Null
}
$md.Add('') | Out-Null
$md.Add("**KB Quality Index (composite, weighted):** $qualityIndex / 100") | Out-Null
$md.Add('') | Out-Null
$md.Add('## MODEL PROVENANCE (RULE 20) AND FAMILY SEPARATION (RULE 19)') | Out-Null
$md.Add('') | Out-Null
$md.Add("**Rule 20 actuals coverage:** $($phaseProvenance.Count) phase log entries found in ``sources/pipeline_state.md``.") | Out-Null
$md.Add("**Rule 19 family-separation status:** ``$($rule19.OverallStatus)``") | Out-Null
if ($rule19_methodology_note) { $md.Add('') | Out-Null; $md.Add($rule19_methodology_note) | Out-Null }
$md.Add('') | Out-Null
$md.Add('### Cross-phase verification pairs (per Rule 19 canonical pairs)') | Out-Null
$md.Add('') | Out-Null
$md.Add('| Verification pair | Verdict | Verifier family | Producer family | Verifier status | Producer status |') | Out-Null
$md.Add('|---|---|---|---|---|---|') | Out-Null
foreach ($r in $rule19.PairResults) {
    $detail = if ($r.Detail) { " — $($r.Detail)" } else { '' }
    $md.Add("| $(Escape-Md $r.Pair) | $($r.Verdict)$detail | $(Escape-Md $r.VerifierFamily) | $(Escape-Md $r.ProducerFamily) | $(Escape-Md $r.VerifierStatus) | $(Escape-Md $r.ProducerStatus) |") | Out-Null
}
if ($rule19.PairResults.Count -eq 0) { $md.Add('| — | INSUFFICIENT_DATA | — | — | — | — |') | Out-Null }
$md.Add('') | Out-Null
if ($rule19.WithinPhaseFindings.Count -gt 0) {
    $md.Add('### Within-phase distinctness findings (Builder A/B + Lead-as-Builder detector)') | Out-Null
    $md.Add('') | Out-Null
    $md.Add('| Phase | Check | Verdict | Detail |') | Out-Null
    $md.Add('|---|---|---|---|') | Out-Null
    foreach ($f in $rule19.WithinPhaseFindings) {
        $md.Add("| $(Escape-Md $f.Phase) | $(Escape-Md $f.Check) | $($f.Verdict) | $(Escape-Md $f.Detail) |") | Out-Null
    }
    $md.Add('') | Out-Null
}
$md.Add('### Per-phase actuals (Rule 20)') | Out-Null
$md.Add('') | Out-Null
if ($phaseProvenance.Count -eq 0) {
    $md.Add('_No Rule 20 actuals found in `sources/pipeline_state.md`. The build pre-dates v3.1.8 Rule 20 (Model Provenance Honesty) or the orchestrator failed to log per-phase actuals. Rule 19 family-separation could not be verified against actuals — only the intended `model_assignment` block (below) was available._') | Out-Null
} else {
    $md.Add('| Phase | Role | Intended handle | Actual model id | Actual provider | Actual family | Dispatch status | Notes |') | Out-Null
    $md.Add('|---|---|---|---|---|---|---|---|') | Out-Null
    foreach ($e in $phaseProvenance) {
        $md.Add("| $(Escape-Md $e.PhaseId) | $(Escape-Md $e.Role) | $(Escape-Md $e.IntendedHandle) | $(Escape-Md $e.ActualModelId) | $(Escape-Md $e.ActualProvider) | $(Escape-Md $e.ActualFamily) | $(Escape-Md $e.DispatchStatus) | $(Escape-Md $e.Notes) |") | Out-Null
    }
}
$md.Add('') | Out-Null
if ($rule19.AcknowledgedOptOuts.Count -gt 0) {
    $md.Add('### Acknowledged Rule 19 opt-outs') | Out-Null
    $md.Add('') | Out-Null
    foreach ($o in $rule19.AcknowledgedOptOuts) { $md.Add("- $o") | Out-Null }
    $md.Add('') | Out-Null
    $md.Add('Affected scorecard dimensions (per ``audit-templates/kb-quality-dimensions.yaml`` § ``family_separation_exception_handling``):') | Out-Null
    foreach ($t in $tagged_dimensions) { $md.Add("- $t — tagged ``verification-independence-degraded``") | Out-Null }
    $md.Add('') | Out-Null
}
$md.Add('## QUALITY DIMENSIONS (DETAILED)') | Out-Null
foreach ($d in $dimensions) {
    $md.Add('') | Out-Null
    $md.Add("### $($d.Name)") | Out-Null
    $md.Add("- Score: **$($d.Score)** (threshold ≥$($d.Threshold); verdict $($d.Verdict))") | Out-Null
    $md.Add("- Measurement method: $($d.Method)") | Out-Null
    $md.Add('- Underlying data:') | Out-Null
    foreach ($key in $d.Data.Keys) { $md.Add("  - ${key}: $($d.Data[$key] -join ', ')") | Out-Null }
    $md.Add("- Threshold rationale: v3 default threshold for this scorecard dimension; weight $($weights[$d.Name]).") | Out-Null
}
$md.Add('') | Out-Null
$md.Add('## OPEN ITEMS') | Out-Null
$md.Add('') | Out-Null
$md.Add('| ID | Severity | Item | Source artifact | Recommended action |') | Out-Null
$md.Add('|---|---|---|---|---|') | Out-Null
$i = 1
foreach ($m in @($missingStructure.Relative)) { $md.Add("| OQ-$i | blocker | Missing expected structure: $m | KB root | Create/populate before final ship. |") | Out-Null; $i++ }
foreach ($m in @($missingArtifacts | Select-Object -Unique)) { $md.Add("| OQ-$i | blocker | Missing expected artifact: $m | sources/audit | Complete upstream phase or rerun scorecard after artifact exists. |") | Out-Null; $i++ }
if ($rule19.HasSilentViolation) {
    foreach ($v in @($rule19.PairResults | Where-Object { $_.Verdict -eq 'SILENTLY_VIOLATED' })) {
        $md.Add("| OQ-$i | blocker | Rule 19 silently violated: $(Escape-Md $v.Pair) (both families = $(Escape-Md $v.VerifierFamily)) | sources/pipeline_state.md | Either redo the affected verification phase with cross-family model OR explicitly acknowledge per Phase 0.0 opt-out and re-run scorecard. |") | Out-Null; $i++
    }
    foreach ($v in @($rule19.WithinPhaseFindings | Where-Object { $_.Verdict -eq 'SILENTLY_VIOLATED' })) {
        $md.Add("| OQ-$i | blocker | Rule 19 within-phase violation: Phase $(Escape-Md $v.Phase) — $(Escape-Md $v.Check) | sources/pipeline_state.md | $(Escape-Md $v.Detail) |") | Out-Null; $i++
    }
}
if ($rule19.HasInsufficientData -and $phaseProvenance.Count -gt 0) {
    $md.Add("| OQ-$i | material | Rule 20 actuals incomplete — some canonical verification phases lack per-phase actuals in pipeline_state.md | sources/pipeline_state.md | Backfill missing phase log entries with intended_handle / actual_model_id / actual_provider / actual_family / dispatch_status. |") | Out-Null; $i++
}
if ($phaseProvenance.Count -eq 0) {
    $md.Add("| OQ-$i | material | Rule 20 actuals entirely absent from pipeline_state.md (build pre-dates v3.1.8 or orchestrator did not log dispatches) | sources/pipeline_state.md | Future builds: orchestrator MUST append per-phase actuals after each dispatch per Rule 20. This build: Rule 19 family-separation could not be verified against actuals. |") | Out-Null; $i++
}
if ($i -eq 1) { $md.Add('| — | — | No missing artifacts detected by mechanical scorecard. | — | — |') | Out-Null }
$md.Add('') | Out-Null
$md.Add('## VERSION HISTORY') | Out-Null
$md.Add('') | Out-Null
$md.Add('| Version | Generated | KB Quality Index | Notes |') | Out-Null
$md.Add('|---|---|---:|---|') | Out-Null
foreach ($h in @($history | Select-Object -Last 10)) { $md.Add("| $($h.framework_version) | $($h.generated_at) | $($h.kb_quality_index) | $($h.verdict) |") | Out-Null }
$md.Add('') | Out-Null
$md.Add('## METHODOLOGY APPENDIX') | Out-Null
$md.Add('') | Out-Null
$md.Add('Scores are generated mechanically from v3 build artifacts. No model calls are made. Missing artifacts generate BUILD-INCOMPLETE rather than a runtime failure. Dimension formulas are intentionally conservative and should be tuned only through audit-templates/kb-quality-dimensions.yaml or a future framework version.') | Out-Null
$md.Add('') | Out-Null
$md.Add('Rule 19 (Model-Family Separation) is evaluated against per-phase ACTUALS recorded in `sources/pipeline_state.md` per Rule 20 (Model Provenance Honesty). Intended Phase 0.0 assignments are NOT used for the Rule 19 score — only what the adapter actually dispatched. Canonical verification pairs are sourced from `01-shared-axioms.md` Rule 19: (1.2 ≠ 1.1), (5.4 ≠ 5.2), (6.4 ≠ 5.2), (7.0 ≠ 5.2 and 7.0 ≠ 6.4), (8.0 ≠ 6.4). Within-phase distinctness checks Builder A vs Builder B and detect the v3.1.6 anti-pattern where Lead silently substitutes for one or both Builders.') | Out-Null
if ($modelAssignment['raw_excerpt']) { $md.Add('') | Out-Null; $md.Add('### Intended model assignment excerpt (NOT used for Rule 19 score — for context only)') | Out-Null; $md.Add('```text') | Out-Null; $md.Add($modelAssignment['raw_excerpt']) | Out-Null; $md.Add('```') | Out-Null }

$md -join "`n" | Set-Content -LiteralPath $scorecardPath -Encoding UTF8

Write-Host "Quality scorecard: $overallVerdict ($qualityIndex/100) — $scorecardPath"
switch ($overallVerdict) {
    'PASS' { exit 0 }
    'FAIL' { exit 2 }
    default { exit 1 }
}
