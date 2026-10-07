<#
.SYNOPSIS
    Validate-Pipeline.ps1 — v3.1.12 KB Creation Framework phase-contracts DAG validator.

.DESCRIPTION
    Validates audit-templates/phase-contracts.yaml against:
      1. audit-templates/phase-contracts.schema.json (JSON Schema via Test-Json).
      2. DAG checks:
         (a) Every phase's `consumes` entry MUST appear in an earlier phase's `produces` list,
             OR in the top-level `external_inputs` list. Catches "Phase 5.4 needs X but X is not produced
             by any earlier phase" gaps mechanically — modeled on haystack's pipeline.connect() validation.
         (b) Every phase's `produces` entry SHOULD be consumed by some later phase (orphan-production WARN).
         (c) No cycles in the produces -> consumes graph.
      3. Rule 19 pair consistency:
         (a) `rule_19_pair` MUST reference existing phase_ids.
         (b) verifier phase must execute AFTER producer phase in the canonical phase ordering.

    Optionally (with `-PipelineStatePath`) cross-checks against an actuals file:
      4. Every Rule 19 verifier pair where both phases have logged entries: actual_family of verifier
         MUST differ from actual_family of producer (matches v3.1.9 Quality Scorecard check; provides
         pre-build validation rather than post-build catch).
      5. Every phase that executed (per pipeline_state.yaml phase_log) MUST have a phase_id present in
         phase-contracts.yaml — unexpected phase IDs in the log are themselves a Rule 20 integrity flag.

    Exits 0 on valid, 1 on contract violations, 2 on JSON Schema failures, 3 on file errors.

.PARAMETER ContractsPath
    Path to phase-contracts.yaml. Default: framework's audit-templates/phase-contracts.yaml.

.PARAMETER SchemaPath
    Path to phase-contracts.schema.json. Default: framework's audit-templates/phase-contracts.schema.json.

.PARAMETER PipelineStatePath
    Optional path to a pipeline_state.yaml to cross-check against (Rule 19 actuals).

.PARAMETER Strict
    Treat WARN findings as ERROR.

.PARAMETER Json
    Emit a single JSON result object.

.EXITCODES
    0 = VALID. 1 = CONTRACT-VIOLATION. 2 = SCHEMA-INVALID. 3 = FILE-ERROR.

.RELATED
    Validate-PipelineState.ps1 — runtime pipeline_state.yaml linter (Rule 20 integrity).
    Generate-QualityScorecard.ps1 — Rule 19 evaluation against actuals.
    01-shared-axioms.md — Rule 19 + Rule 20.
#>

[CmdletBinding()]
param(
    [string]$ContractsPath = '',
    [string]$SchemaPath = '',
    [string]$PipelineStatePath = '',
    [switch]$Strict,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Script:FrameworkRoot = $PSScriptRoot
if (-not $ContractsPath) { $ContractsPath = Join-Path $Script:FrameworkRoot 'audit-templates\phase-contracts.yaml' }
if (-not $SchemaPath)    { $SchemaPath    = Join-Path $Script:FrameworkRoot 'audit-templates\phase-contracts.schema.json' }

# ============ Inline YAML parser (duplicate of Validate-PipelineState.ps1's parser) ============
# Kept inline to avoid coupling/dot-sourcing issues. Future refactor: extract to lib/Yaml.psm1.
function Strip-YamlComment2 { param([string]$Line); if ($null -eq $Line) { return $null }; if ($Line -match '^(?<body>(?:[^''"#]|"[^"]*"|''[^'']*'')*)#') { return $matches['body'].TrimEnd() }; return $Line }
function Strip-Quotes2 { param([string]$V); if ($null -eq $V) { return $null }; $t = $V.Trim(); if ($t.Length -ge 2 -and (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'")))) { return $t.Substring(1, $t.Length - 2) }; return $t }
function ConvertTo-YamlScalar2 { param([string]$V); if ($null -eq $V) { return $null }; $t = $V.Trim(); if ($t -eq '' -or $t -eq '~') { return $null }; $low = $t.ToLowerInvariant(); if ($low -eq 'null') { return $null }; if ($low -in @('true','yes','on')) { return $true }; if ($low -in @('false','no','off')) { return $false }; if ($t -match '^-?\d+$') { return [int]$t }; return (Strip-Quotes2 $t) }
function ConvertFrom-FlowList2 { param([string]$V); $inner = ($V.Trim()).TrimStart('[').TrimEnd(']'); if ([string]::IsNullOrWhiteSpace($inner)) { return ,@() }; $out = New-Object 'System.Collections.Generic.List[object]'; $buf = ''; $depth = 0; $inSingle = $false; $inDouble = $false; foreach ($ch in $inner.ToCharArray()) { if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; $buf += $ch; continue }; if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; $buf += $ch; continue }; if (-not $inSingle -and -not $inDouble) { if ($ch -eq '[' -or $ch -eq '{') { $depth++ } elseif ($ch -eq ']' -or $ch -eq '}') { $depth-- } elseif ($ch -eq ',' -and $depth -eq 0) { $out.Add((ConvertTo-YamlScalar2 $buf)) | Out-Null; $buf = ''; continue } }; $buf += $ch }; if ($buf.Length -gt 0) { $out.Add((ConvertTo-YamlScalar2 $buf)) | Out-Null }; return ,$out.ToArray() }
function Get-LastKey2 { param($Map); $keys = @($Map.Keys); if ($keys.Count -eq 0) { return $null }; return $keys[$keys.Count - 1] }

function ConvertFrom-YamlText2 {
    param([string]$Text)
    $tokens = [System.Collections.Generic.List[object]]::new()
    foreach ($raw in ($Text -split "`r?`n")) {
        $stripped = Strip-YamlComment2 $raw
        if ($null -eq $stripped -or $stripped.Trim() -eq '') { continue }
        $match = [regex]::Match($stripped, '^(\s*)(.*)$')
        $indent = $match.Groups[1].Value.Length
        $content = $match.Groups[2].Value
        $kind = if ($content.StartsWith('- ')) { 'list-item' } else { 'map-entry' }
        $tokens.Add([pscustomobject]@{ Indent = $indent; Content = $content; Kind = $kind }) | Out-Null
    }
    $root = [ordered]@{}
    $stack = New-Object 'System.Collections.Generic.Stack[object]'
    $stack.Push([pscustomobject]@{ Indent = -1; Container = $root; Kind = 'map' }) | Out-Null

    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $t = $tokens[$i]
        while ($stack.Count -gt 1) {
            $top = $stack.Peek()
            if ($top.Indent -gt $t.Indent) { [void]$stack.Pop(); continue }
            if ($top.Indent -eq $t.Indent) {
                if ($top.Kind -eq 'list' -and $t.Kind -eq 'list-item') { break }
                if ($top.Kind -eq 'map' -and $t.Kind -eq 'map-entry') { break }
                [void]$stack.Pop(); continue
            }
            break
        }
        if ($t.Kind -eq 'list-item') {
            $top = $stack.Peek()
            if ($top.Kind -eq 'list' -and $top.Indent -eq $t.Indent) {
                $listContainer = $top.Container
            } else {
                if ($top.Kind -ne 'map') { throw "YAML: list item at indent $($t.Indent) has no map parent." }
                $lastKey = Get-LastKey2 $top.Container
                if ($null -eq $lastKey) { throw "YAML: list item at indent $($t.Indent) but parent map is empty." }
                $existing = $top.Container[$lastKey]
                if ($null -eq $existing) {
                    $listContainer = New-Object 'System.Collections.Generic.List[object]'
                    $top.Container[$lastKey] = $listContainer
                } elseif ($existing -is [System.Collections.IList] -and -not ($existing -is [string])) {
                    $listContainer = $existing
                } else { throw "YAML: parent key '$lastKey' cannot host a list." }
                $stack.Push([pscustomobject]@{ Indent = $t.Indent; Container = $listContainer; Kind = 'list' }) | Out-Null
            }
            $rest = $t.Content.Substring(2)
            # Distinguish "key: value" list items (item is a map) from "scalar" list items.
            $kvMatch = [regex]::Match($rest, '^([^:#]+?)\s*:\s*(.*)$')
            if ($kvMatch.Success) {
                # Map-shaped item
                $itemMap = [ordered]@{}
                $listContainer.Add($itemMap) | Out-Null
                $stack.Push([pscustomobject]@{ Indent = $t.Indent + 2; Container = $itemMap; Kind = 'map' }) | Out-Null
                $key = $kvMatch.Groups[1].Value.Trim()
                $rhs = $kvMatch.Groups[2].Value
                if ([string]::IsNullOrWhiteSpace($rhs)) { $itemMap[$key] = $null }
                elseif ($rhs.TrimStart().StartsWith('[')) { $itemMap[$key] = ConvertFrom-FlowList2 $rhs }
                else { $itemMap[$key] = ConvertTo-YamlScalar2 $rhs }
            } else {
                # Scalar list item
                $listContainer.Add((ConvertTo-YamlScalar2 $rest)) | Out-Null
            }
        } else {
            $top = $stack.Peek()
            if ($top.Kind -ne 'map') { throw "YAML: map entry at indent $($t.Indent) but top is list." }
            $lastKey = Get-LastKey2 $top.Container
            $existing = if ($lastKey) { $top.Container[$lastKey] } else { '__no_last_key__' }
            $shouldPromote = ($top.Indent -lt $t.Indent) -and $lastKey -and ($null -eq $existing)
            if ($shouldPromote) {
                $newMap = [ordered]@{}
                $top.Container[$lastKey] = $newMap
                $stack.Push([pscustomobject]@{ Indent = $t.Indent; Container = $newMap; Kind = 'map' }) | Out-Null
                $top = $stack.Peek()
            }
            $m = [regex]::Match($t.Content, '^([^:]+?)\s*:\s*(.*)$')
            if (-not $m.Success) { throw "YAML: cannot parse '$($t.Content)'." }
            $key = $m.Groups[1].Value.Trim()
            $rhs = $m.Groups[2].Value
            if ([string]::IsNullOrWhiteSpace($rhs)) { $top.Container[$key] = $null }
            elseif ($rhs.TrimStart().StartsWith('[')) { $top.Container[$key] = ConvertFrom-FlowList2 $rhs }
            else { $top.Container[$key] = ConvertTo-YamlScalar2 $rhs }
        }
    }
    return $root
}

function ConvertTo-CleanObject2 {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) {
        $obj = [ordered]@{}
        foreach ($k in $Value.Keys) { $obj[[string]$k] = ConvertTo-CleanObject2 $Value[$k] }
        return [pscustomobject]$obj
    }
    if ($Value -is [System.Collections.IList] -and -not ($Value -is [string])) {
        $arr = @()
        foreach ($item in $Value) { $arr += ,(ConvertTo-CleanObject2 $item) }
        return ,$arr
    }
    return $Value
}

function Get-Prop2 { param($Obj, [string]$Name); if ($null -eq $Obj) { return $null }; if ($Obj -is [System.Collections.IDictionary]) { if ($Obj.Contains($Name)) { return $Obj[$Name] }; return $null }; $p = $Obj.PSObject.Properties[$Name]; if ($p) { return $p.Value }; return $null }

# ============ Findings ============
$Script:Findings2 = [System.Collections.Generic.List[object]]::new()
function Add-Finding2 { param([string]$Severity, [string]$Rule, [string]$Message); $Script:Findings2.Add([pscustomobject]@{ severity = $Severity; rule = $Rule; message = $Message }) | Out-Null }

function Emit-PipelineResult {
    param([int]$Exit)
    $verdict = switch ($Exit) { 0 {'VALID'} 1 {'CONTRACT-VIOLATION'} 2 {'SCHEMA-INVALID'} default {'FILE-ERROR'} }
    $err = @($Script:Findings2 | Where-Object { $_.severity -eq 'ERROR' }).Count
    $wrn = @($Script:Findings2 | Where-Object { $_.severity -eq 'WARN'  }).Count
    $inf = @($Script:Findings2 | Where-Object { $_.severity -eq 'INFO'  }).Count
    $payload = [ordered]@{
        contracts_path = $ContractsPath
        pipeline_state_path = $PipelineStatePath
        verdict = $verdict
        exit = $Exit
        counts = [ordered]@{ error = $err; warn = $wrn; info = $inf }
        findings = @($Script:Findings2)
    }
    if ($Json) { $payload | ConvertTo-Json -Depth 8 }
    else {
        Write-Host ("Contracts:      {0}" -f $ContractsPath)
        if ($PipelineStatePath) { Write-Host ("Pipeline state: {0}" -f $PipelineStatePath) }
        Write-Host ("Verdict:        {0} (exit {1})" -f $verdict, $Exit)
        Write-Host ("Counts:         ERROR={0} WARN={1} INFO={2}" -f $err, $wrn, $inf)
        if ($Script:Findings2.Count -gt 0) {
            Write-Host ''
            foreach ($f in $Script:Findings2) {
                $color = switch ($f.severity) { 'ERROR' {'Red'} 'WARN' {'Yellow'} default {'Gray'} }
                Write-Host ("  [{0}] {1}: {2}" -f $f.severity, $f.rule, $f.message) -ForegroundColor $color
            }
        }
    }
    exit $Exit
}

# ============ Main ============
try {
    if (-not (Test-Path -LiteralPath $ContractsPath -PathType Leaf)) {
        Add-Finding2 'ERROR' 'file' "phase-contracts.yaml not found at '$ContractsPath'"; Emit-PipelineResult -Exit 3
    }
    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        Add-Finding2 'ERROR' 'schema' "Schema not found at '$SchemaPath'"; Emit-PipelineResult -Exit 3
    }

    $contractsText = Get-Content -LiteralPath $ContractsPath -Raw -Encoding UTF8
    $parsed = $null
    try { $parsed = ConvertFrom-YamlText2 -Text $contractsText } catch {
        Add-Finding2 'ERROR' 'yaml-parse' "phase-contracts.yaml parse failed: $($_.Exception.Message)"; Emit-PipelineResult -Exit 3
    }
    $contracts = ConvertTo-CleanObject2 $parsed
    $contractsJson = $contracts | ConvertTo-Json -Depth 20

    # Step 1: JSON Schema validation
    $schemaErrors = $null
    $valid = Test-Json -Json $contractsJson -SchemaFile $SchemaPath -ErrorVariable schemaErrors -ErrorAction SilentlyContinue
    if (-not $valid) {
        foreach ($e in @($schemaErrors)) { Add-Finding2 'ERROR' 'schema' ("Phase-contracts schema violation: " + [string]$e) }
        if (@($schemaErrors).Count -eq 0) { Add-Finding2 'ERROR' 'schema' 'Phase-contracts schema validation failed without details.' }
        Emit-PipelineResult -Exit 2
    }

    # Build artifact production index (artifact path -> list of phase_ids that produce it)
    $produced = @{}
    $external = @(Get-Prop2 $contracts 'external_inputs')
    foreach ($e in $external) { if ($e) { $produced[[string]$e] = @('external') } }
    $phases = @(Get-Prop2 $contracts 'phases')
    if ($phases.Count -gt 0) {
    }
    foreach ($p in $phases) {
        $phaseIdVal = [string](Get-Prop2 $p 'phase_id')
        $prod = @(Get-Prop2 $p 'produces')
        foreach ($a in $prod) {
            if (-not $produced.ContainsKey([string]$a)) { $produced[[string]$a] = @() }
            $produced[[string]$a] += $phaseIdVal
        }
    }

    # Step 2: DAG validation — every consumed artifact must be produced earlier
    # Phase ordering: by lexicographic phase_id (treat as a.b string sort with numeric components).
    function Compare-PhaseId { param([string]$A, [string]$B)
        $partsA = $A -split '\.'; $partsB = $B -split '\.'
        for ($i = 0; $i -lt [Math]::Max($partsA.Count, $partsB.Count); $i++) {
            $pa = if ($i -lt $partsA.Count) { $partsA[$i] } else { '0' }
            $pb = if ($i -lt $partsB.Count) { $partsB[$i] } else { '0' }
            $na = 0; $nb = 0
            if ([int]::TryParse($pa, [ref]$na) -and [int]::TryParse($pb, [ref]$nb)) {
                if ($na -ne $nb) { return ($na - $nb) }
            } else {
                $c = [string]::Compare($pa, $pb)
                if ($c -ne 0) { return $c }
            }
        }
        return 0
    }
    $orderedPhases = $phases | Sort-Object @{ Expression = { $_.phase_id } }
    # Actually sort using our comparer:
    $orderedPhases = [Linq.Enumerable]::ToArray([Linq.Enumerable]::OrderBy[object, object]($phases, [Func[object, object]] { param($x) $x.phase_id }))

    foreach ($p in $phases) {
        $phaseIdVal = [string](Get-Prop2 $p 'phase_id')
        $cons = @(Get-Prop2 $p 'consumes')
        foreach ($artifact in $cons) {
            $artifactStr = [string]$artifact
            if (-not $produced.ContainsKey($artifactStr)) {
                Add-Finding2 'ERROR' 'dag-missing-producer' "Phase $($phaseIdVal) consumes '${artifactStr}' but no earlier phase produces it (and it's not in external_inputs)."
                continue
            }
            # Check producer ordering: every producer must be earlier than this phase, OR be 'external'
            $producers = $produced[$artifactStr]
            $hasEarlier = $false
            foreach ($prodPid in $producers) {
                if ($prodPid -eq 'external') { $hasEarlier = $true; break }
                if ((Compare-PhaseId $prodPid $phaseIdVal) -lt 0) { $hasEarlier = $true; break }
                if ($prodPid -eq $phaseIdVal) { $hasEarlier = $true; break }  # in-place revision (e.g., 3.0 produces what 1.3 produced)
            }
            if (-not $hasEarlier) {
                Add-Finding2 'ERROR' 'dag-ordering' "Phase $($phaseIdVal) consumes '${artifactStr}' but its only producer(s) [$($producers -join ', ')] come AFTER this phase. Out-of-order DAG."
            }
        }
    }

    # Orphan productions — produced but never consumed
    $consumedSet = @{}
    foreach ($p in $phases) {
        foreach ($a in @(Get-Prop2 $p 'consumes')) { $consumedSet[[string]$a] = $true }
    }
    foreach ($a in $produced.Keys) {
        if ($produced[$a] -contains 'external') { continue }
        if (-not $consumedSet.ContainsKey($a)) {
            # Final deliverables are allowed orphans (full/, audit/, etc.)
            $isDeliverable = $a -match '^(full|authority|practice|audit|index\.md|table-of-authorities\.md|opencode\.json|sources/audit_report\.md|sources/stress_test|sources/quality_tier_audit|sources/factcheck_|sources/comparison_report|sources/scoping_critique|sources/topic-structure-critique|sources/lead-review|sources/register_lint|sources/assembly_critique|sources/single-source-inventory|sources/compliance-check|sources/post_assembly|sources/authority_view|sources/filename_validation|sources/model_assignment_validation|sources/pipeline_state\.yaml)'
            if (-not $isDeliverable) {
                Add-Finding2 'WARN' 'dag-orphan-production' "Artifact '${a}' produced by phases [$($produced[$a] -join ', ')] but no later phase consumes it. Possible dead output."
            }
        }
    }

    # Step 3: rule_19_pair consistency
    $phaseIdSet = @{}
    foreach ($p in $phases) { $phaseIdSet[[string](Get-Prop2 $p 'phase_id')] = $true }
    foreach ($p in $phases) {
        $pair = @(Get-Prop2 $p 'rule_19_pair')
        if ($pair.Count -eq 2) {
            $verifierId = [string]$pair[0]; $producerId = [string]$pair[1]
            if (-not $phaseIdSet.ContainsKey($verifierId)) { Add-Finding2 'ERROR' 'rule-19-pair' "Phase $([string](Get-Prop2 $p 'phase_id')) rule_19_pair references unknown verifier phase '$verifierId'." }
            if (-not $phaseIdSet.ContainsKey($producerId)) { Add-Finding2 'ERROR' 'rule-19-pair' "Phase $([string](Get-Prop2 $p 'phase_id')) rule_19_pair references unknown producer phase '$producerId'." }
            if ($phaseIdSet.ContainsKey($verifierId) -and $phaseIdSet.ContainsKey($producerId)) {
                if ((Compare-PhaseId $verifierId $producerId) -le 0) {
                    Add-Finding2 'ERROR' 'rule-19-pair-ordering' "Phase $([string](Get-Prop2 $p 'phase_id')) rule_19_pair: verifier '$verifierId' must execute AFTER producer '$producerId' (got verifier <= producer in phase ordering)."
                }
            }
        }
    }

    # Step 4: cross-check against pipeline_state.yaml actuals (if provided)
    if ($PipelineStatePath -and (Test-Path -LiteralPath $PipelineStatePath -PathType Leaf)) {
        $stateText = Get-Content -LiteralPath $PipelineStatePath -Raw -Encoding UTF8
        $stateParsed = $null
        try { $stateParsed = ConvertFrom-YamlText2 -Text $stateText } catch {
            Add-Finding2 'ERROR' 'state-parse' "pipeline_state.yaml parse failed: $($_.Exception.Message)"
        }
        if ($stateParsed) {
            $state = ConvertTo-CleanObject2 $stateParsed
            $log = @(Get-Prop2 $state 'phase_log')
            $byPhase = @{}
            foreach ($entry in $log) {
                $phaseIdVal = ([string](Get-Prop2 $entry 'phase_id') -split '-')[0]
                if (-not $byPhase.ContainsKey($phaseIdVal)) { $byPhase[$phaseIdVal] = @() }
                $byPhase[$phaseIdVal] += [pscustomobject]@{ family = [string](Get-Prop2 $entry 'actual_family'); status = [string](Get-Prop2 $entry 'dispatch_status'); role = [string](Get-Prop2 $entry 'role') }
            }

            # Unknown phase_id in log
            foreach ($phaseIdVal in $byPhase.Keys) {
                if (-not $phaseIdSet.ContainsKey($phaseIdVal)) {
                    Add-Finding2 'WARN' 'state-unknown-phase' "pipeline_state.yaml logs phase_id '$phaseIdVal' but no contract entry exists. Either the orchestrator invented a phase or phase-contracts.yaml is missing this phase."
                }
            }

            # Rule 19 pair check against actuals
            foreach ($p in $phases) {
                $pair = @(Get-Prop2 $p 'rule_19_pair')
                if ($pair.Count -ne 2) { continue }
                $v = [string]$pair[0]; $pr = [string]$pair[1]
                if (-not $byPhase.ContainsKey($v) -or -not $byPhase.ContainsKey($pr)) { continue }
                $vFams = @($byPhase[$v] | ForEach-Object { $_.family.ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
                $pFams = @($byPhase[$pr] | ForEach-Object { $_.family.ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
                $overlap = @($vFams | Where-Object { $pFams -contains $_ })
                if ($overlap.Count -gt 0) {
                    $isOptOut = @($byPhase[$v]) + @($byPhase[$pr]) | Where-Object { $_.status -eq 'failed-then-acknowledged-opt-out' }
                    if (@($isOptOut).Count -eq 0) {
                        Add-Finding2 'ERROR' 'rule-19-actuals' "Rule 19 violation in actuals: verifier phase '$v' (family $($vFams -join ',')) overlaps producer phase '$pr' (family $($pFams -join ',')). Cross-family verification was not achieved."
                    }
                }
            }
        }
    }

    # Final
    $err = @($Script:Findings2 | Where-Object { $_.severity -eq 'ERROR' }).Count
    $wrn = @($Script:Findings2 | Where-Object { $_.severity -eq 'WARN'  }).Count
    if ($err -gt 0) { Emit-PipelineResult -Exit 1 }
    if ($Strict -and $wrn -gt 0) { Emit-PipelineResult -Exit 1 }
    Emit-PipelineResult -Exit 0

} catch {
    Add-Finding2 'ERROR' 'script-error' "Unexpected error: $($_.Exception.Message). $($_.ScriptStackTrace)"
    Emit-PipelineResult -Exit 3
}
