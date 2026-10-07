<#
.SYNOPSIS
    Validate-PipelineState.ps1 — v3.1.11 KB Creation Framework pipeline-state.yaml linter.

.DESCRIPTION
    Validates sources/pipeline_state.yaml against:
      1. audit-templates/pipeline-state.schema.json (JSON Schema via Test-Json -SchemaFile).
      2. Rule 20 integrity cross-checks:
         (a) every phase_log[].intended_handle MUST be one of the handles declared in model_assignment
             or in mid_build_overrides[].new_handle. A phase_log entry whose intended_handle is invented
             per phase (not in either) is itself a Rule 20 violation.
         (b) every phase_log[].actual_family SHOULD match the family declared in model-registry.yaml
             for the actual_model_id, when the model is resolvable from the registry.
         (c) for dispatched-after-override entries, there SHOULD be a corresponding mid_build_overrides
             entry whose new_handle matches the entry's intended_handle or actual_model_id.
      3. Rule 19 minimum coverage:
         (a) Phase 0.0 entry present.
         (b) at least one fact-check / audit entry (5.4, 6.4, or 7.0) present.
         (c) when phase 5.2 entries exist, both Builder A and Builder B must have logged.

    The full Rule 19 cross-phase pair evaluation lives in Generate-QualityScorecard.ps1.

.PARAMETER Path
    pipeline_state.yaml path. Default: ".\sources\pipeline_state.yaml".

.PARAMETER SchemaPath
    JSON Schema path. Default: framework's audit-templates\pipeline-state.schema.json.

.PARAMETER RegistryPath
    model-registry.yaml path. Optional; if absent, family-lookup cross-check is skipped.

.PARAMETER Strict
    Treat WARN findings as ERROR (raises exit to 1 even when only WARN findings exist).

.PARAMETER Json
    Emit a single JSON result object instead of human-readable text.

.EXITCODES
    0 = VALID. 1 = RULE-VIOLATION (Rule 20 integrity or Rule 19 minimum coverage).
    2 = SCHEMA-INVALID (JSON Schema validation failed). 3 = FILE-ERROR.

.RELATED
    01-shared-axioms.md Rule 19 / Rule 20.
    audit-templates/pipeline-state.schema.json.
    examples/pipeline-state.example.yaml.
    Generate-QualityScorecard.ps1.
#>

[CmdletBinding()]
param(
    [string]$Path = '.\sources\pipeline_state.yaml',
    [string]$SchemaPath = '',
    [string]$RegistryPath = '',
    [switch]$Strict,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Script:FrameworkRoot = $PSScriptRoot
if (-not $SchemaPath) { $SchemaPath = Join-Path $Script:FrameworkRoot 'audit-templates\pipeline-state.schema.json' }
if (-not $RegistryPath) {
    $candidate = Join-Path $Script:FrameworkRoot 'model-registry.yaml'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $RegistryPath = $candidate }
}

# Findings collector
$Script:Findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding {
    param([string]$Severity, [string]$Rule, [string]$Message, $Context = $null)
    $Script:Findings.Add([pscustomobject]@{
        severity = $Severity
        rule = $Rule
        message = $Message
        context = $Context
    }) | Out-Null
}

# ============ Iterative YAML parser ============
# Handles: scalar key:value, nested maps via indent, lists of maps with `- ` prefix,
# inline flow lists `[a, b, c]`, quoted strings, ISO 8601 timestamps, true/false/null.

function Strip-YamlComment {
    param([string]$Line)
    if ($null -eq $Line) { return $null }
    if ($Line -match '^(?<body>(?:[^''"#]|"[^"]*"|''[^'']*'')*)#') { return $matches['body'].TrimEnd() }
    return $Line
}

function Strip-Quotes {
    param([string]$V)
    if ($null -eq $V) { return $null }
    $t = $V.Trim()
    if ($t.Length -ge 2 -and (($t.StartsWith('"') -and $t.EndsWith('"')) -or ($t.StartsWith("'") -and $t.EndsWith("'")))) {
        return $t.Substring(1, $t.Length - 2)
    }
    return $t
}

function ConvertTo-YamlScalar {
    param([string]$V)
    if ($null -eq $V) { return $null }
    $t = $V.Trim()
    if ($t -eq '' -or $t -eq '~') { return $null }
    $low = $t.ToLowerInvariant()
    if ($low -eq 'null') { return $null }
    if ($low -in @('true','yes','on')) { return $true }
    if ($low -in @('false','no','off')) { return $false }
    if ($t -match '^-?\d+$') { return [int]$t }
    return (Strip-Quotes $t)
}

function ConvertFrom-FlowList {
    param([string]$V)
    $inner = ($V.Trim()).TrimStart('[').TrimEnd(']')
    if ([string]::IsNullOrWhiteSpace($inner)) { return ,@() }
    $out = New-Object 'System.Collections.Generic.List[object]'
    $buf = ''
    $depth = 0
    $inSingle = $false; $inDouble = $false
    foreach ($ch in $inner.ToCharArray()) {
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; $buf += $ch; continue }
        if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; $buf += $ch; continue }
        if (-not $inSingle -and -not $inDouble) {
            if ($ch -eq '[' -or $ch -eq '{') { $depth++ }
            elseif ($ch -eq ']' -or $ch -eq '}') { $depth-- }
            elseif ($ch -eq ',' -and $depth -eq 0) {
                $out.Add((ConvertTo-YamlScalar $buf)) | Out-Null
                $buf = ''
                continue
            }
        }
        $buf += $ch
    }
    if ($buf.Length -gt 0) { $out.Add((ConvertTo-YamlScalar $buf)) | Out-Null }
    return ,$out.ToArray()
}

# Tokenize: returns array of [indent, content, kind] where kind is 'list-item' or 'map-entry'.
function ConvertFrom-YamlText {
    param([string]$Text)

    # Pre-tokenize
    $tokens = [System.Collections.Generic.List[object]]::new()
    foreach ($raw in ($Text -split "`r?`n")) {
        $stripped = Strip-YamlComment $raw
        if ($null -eq $stripped -or $stripped.Trim() -eq '') { continue }
        $match = [regex]::Match($stripped, '^(\s*)(.*)$')
        $indent = $match.Groups[1].Value.Length
        $content = $match.Groups[2].Value
        $kind = if ($content.StartsWith('- ')) { 'list-item' } else { 'map-entry' }
        $tokens.Add([pscustomobject]@{ Indent = $indent; Content = $content; Kind = $kind }) | Out-Null
    }

    # Parse using an explicit container stack: each frame is { Indent, Container, Kind }
    # where Container is either an [ordered]@{} (map) or List[object] (list of maps).
    # Top-level is always a map.
    $root = [ordered]@{}
    $stack = New-Object 'System.Collections.Generic.Stack[object]'
    $stack.Push([pscustomobject]@{ Indent = -1; Container = $root; Kind = 'map' }) | Out-Null

    function Get-LastKey { param($Map); $keys = @($Map.Keys); if ($keys.Count -eq 0) { return $null }; return $keys[$keys.Count - 1] }

    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $t = $tokens[$i]

        # Pop frames until top is the correct parent for current token.
        while ($stack.Count -gt 1) {
            $top = $stack.Peek()
            if ($top.Indent -gt $t.Indent) { [void]$stack.Pop(); continue }
            if ($top.Indent -eq $t.Indent) {
                # Same-indent semantics depend on Kind alignment.
                if ($top.Kind -eq 'list' -and $t.Kind -eq 'list-item') { break }
                if ($top.Kind -eq 'map' -and $t.Kind -eq 'map-entry') { break }
                # mismatch — pop and re-evaluate
                [void]$stack.Pop()
                continue
            }
            break  # top.Indent < t.Indent
        }

        if ($t.Kind -eq 'list-item') {
            # Find or create the list container.
            $top = $stack.Peek()
            if ($top.Kind -eq 'list' -and $top.Indent -eq $t.Indent) {
                $listContainer = $top.Container
            } else {
                if ($top.Kind -ne 'map') { throw "YAML: list item at indent $($t.Indent) has no map parent." }
                $lastKey = Get-LastKey $top.Container
                if ($null -eq $lastKey) { throw "YAML: list item at indent $($t.Indent) but parent map is empty." }
                $existing = $top.Container[$lastKey]
                if ($null -eq $existing) {
                    $listContainer = New-Object 'System.Collections.Generic.List[object]'
                    $top.Container[$lastKey] = $listContainer
                } elseif ($existing -is [System.Collections.IList] -and -not ($existing -is [string])) {
                    $listContainer = $existing
                } else {
                    throw "YAML: parent key '$lastKey' at indent $($top.Indent) cannot host a list (already has scalar value)."
                }
                $stack.Push([pscustomobject]@{ Indent = $t.Indent; Container = $listContainer; Kind = 'list' }) | Out-Null
            }

            # Create item map; the rest of the line is its first key:value pair.
            $itemMap = [ordered]@{}
            $listContainer.Add($itemMap) | Out-Null
            $stack.Push([pscustomobject]@{ Indent = $t.Indent + 2; Container = $itemMap; Kind = 'map' }) | Out-Null

            $rest = $t.Content.Substring(2)
            $m = [regex]::Match($rest, '^([^:]+?)\s*:\s*(.*)$')
            if (-not $m.Success) { throw "YAML: list item content '$rest' is not a key:value pair." }
            $key = $m.Groups[1].Value.Trim()
            $rhs = $m.Groups[2].Value
            if ([string]::IsNullOrWhiteSpace($rhs)) {
                $itemMap[$key] = $null
            } elseif ($rhs.TrimStart().StartsWith('[')) {
                $itemMap[$key] = ConvertFrom-FlowList $rhs
            } else {
                $itemMap[$key] = ConvertTo-YamlScalar $rhs
            }
        } else {
            # map-entry: ensure the top frame is a map at our exact indent. If top is at lower
            # indent, promote its last key to a nested map and push that new map frame.
            $top = $stack.Peek()
            if ($top.Kind -ne 'map') { throw "YAML: map entry at indent $($t.Indent) but top frame is a list." }
            # Promote only when last key's value is $null (pending nested block). Already-populated
            # IDictionary values are completed blocks — pushing back into them would mis-attribute
            # sibling top-level keys as nested children.
            $lastKey = Get-LastKey $top.Container
            $existing = if ($lastKey) { $top.Container[$lastKey] } else { '__no_last_key__' }
            $shouldPromote = ($top.Indent -lt $t.Indent) -and $lastKey -and ($null -eq $existing)
            if ($shouldPromote) {
                $newMap = [ordered]@{}
                $top.Container[$lastKey] = $newMap
                $stack.Push([pscustomobject]@{ Indent = $t.Indent; Container = $newMap; Kind = 'map' }) | Out-Null
                $top = $stack.Peek()
            }
            $m = [regex]::Match($t.Content, '^([^:]+?)\s*:\s*(.*)$')
            if (-not $m.Success) { throw "YAML: cannot parse map entry '$($t.Content)'." }
            $key = $m.Groups[1].Value.Trim()
            $rhs = $m.Groups[2].Value
            if ([string]::IsNullOrWhiteSpace($rhs)) {
                $top.Container[$key] = $null
            } elseif ($rhs.TrimStart().StartsWith('[')) {
                $top.Container[$key] = ConvertFrom-FlowList $rhs
            } else {
                $top.Container[$key] = ConvertTo-YamlScalar $rhs
            }
        }
    }

    return $root
}

function ConvertTo-CleanObject {
    # Convert nested IDictionary / IList into PSCustomObject + arrays for clean JSON output.
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) {
        $obj = [ordered]@{}
        foreach ($k in $Value.Keys) { $obj[[string]$k] = ConvertTo-CleanObject $Value[$k] }
        return [pscustomobject]$obj
    }
    if ($Value -is [System.Collections.IList] -and -not ($Value -is [string])) {
        $arr = @()
        foreach ($item in $Value) { $arr += ,(ConvertTo-CleanObject $item) }
        return ,$arr
    }
    return $Value
}

function Get-PropertyValue {
    # Safe property access on PSCustomObject / IDictionary (returns $null when missing).
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [System.Collections.IDictionary]) { if ($Obj.Contains($Name)) { return $Obj[$Name] }; return $null }
    $prop = $Obj.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

# ============ Emit ============
function Emit-Result {
    param([int]$Exit)
    $verdict = switch ($Exit) { 0 {'VALID'} 1 {'RULE-VIOLATION'} 2 {'SCHEMA-INVALID'} default {'FILE-ERROR'} }
    $errorCount = @($Script:Findings | Where-Object { $_.severity -eq 'ERROR' }).Count
    $warnCount  = @($Script:Findings | Where-Object { $_.severity -eq 'WARN'  }).Count
    $infoCount  = @($Script:Findings | Where-Object { $_.severity -eq 'INFO'  }).Count
    $payload = [ordered]@{
        path     = $Path
        verdict  = $verdict
        exit     = $Exit
        counts   = [ordered]@{ error = $errorCount; warn = $warnCount; info = $infoCount }
        findings = @($Script:Findings)
    }
    if ($Json) {
        $payload | ConvertTo-Json -Depth 8
    } else {
        Write-Host ("Path:    {0}" -f $Path)
        Write-Host ("Verdict: {0} (exit {1})" -f $verdict, $Exit)
        Write-Host ("Counts:  ERROR={0} WARN={1} INFO={2}" -f $errorCount, $warnCount, $infoCount)
        if ($Script:Findings.Count -gt 0) {
            Write-Host ''
            foreach ($f in $Script:Findings) {
                $color = switch ($f.severity) { 'ERROR' {'Red'} 'WARN' {'Yellow'} default {'Gray'} }
                Write-Host ("  [{0}] {1}: {2}" -f $f.severity, $f.rule, $f.message) -ForegroundColor $color
            }
        }
    }
    exit $Exit
}

# ============ Main ============
try {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Finding 'ERROR' 'file' "pipeline_state.yaml not found at '$Path'"
        Emit-Result -Exit 3
    }
    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        Add-Finding 'ERROR' 'schema' "Schema file not found at '$SchemaPath'"
        Emit-Result -Exit 3
    }

    $yamlText = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $parsed = $null
    try { $parsed = ConvertFrom-YamlText -Text $yamlText } catch {
        Add-Finding 'ERROR' 'yaml-parse' "YAML parse failed: $($_.Exception.Message)"
        Emit-Result -Exit 3
    }

    $obj = ConvertTo-CleanObject $parsed
    $jsonText = $obj | ConvertTo-Json -Depth 20

    # Step 1 — JSON Schema validation via Test-Json
    $schemaOk = $true
    try {
        $schemaErrors = $null
        $valid = Test-Json -Json $jsonText -SchemaFile $SchemaPath -ErrorVariable schemaErrors -ErrorAction SilentlyContinue
        if (-not $valid) {
            $schemaOk = $false
            foreach ($e in @($schemaErrors)) {
                Add-Finding 'ERROR' 'schema' ("JSON Schema violation: " + [string]$e)
            }
            if (@($schemaErrors).Count -eq 0) {
                Add-Finding 'ERROR' 'schema' 'JSON Schema validation failed without details.'
            }
        }
    } catch {
        Add-Finding 'ERROR' 'schema' "Test-Json failed: $($_.Exception.Message)"
        $schemaOk = $false
    }
    if (-not $schemaOk) { Emit-Result -Exit 2 }

    # Step 2 — Rule 20 integrity
    $ma = Get-PropertyValue $obj 'model_assignment'
    $declared = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($k in @('lead','builder_a','builder_b')) {
        $v = Get-PropertyValue $ma $k
        if ($v) { [void]$declared.Add([string]$v) }
    }
    foreach ($k in @('critic_pool','factcheck_pool_5a_5b_5c','factcheck_pool_5d_5e','factcheck_6b','auditor_7','memo_factcheck_8')) {
        $arr = Get-PropertyValue $ma $k
        if ($arr) { foreach ($h in @($arr)) { if ($h) { [void]$declared.Add([string]$h) } } }
    }
    $overrides = @(Get-PropertyValue $obj 'mid_build_overrides')
    foreach ($o in $overrides) {
        $nh = Get-PropertyValue $o 'new_handle'
        if ($nh) { [void]$declared.Add([string]$nh) }
    }

    $log = @(Get-PropertyValue $obj 'phase_log')
    foreach ($entry in $log) {
        $ih = [string](Get-PropertyValue $entry 'intended_handle')
        $phaseIdVal = [string](Get-PropertyValue $entry 'phase_id')
        $role = [string](Get-PropertyValue $entry 'role')
        $status = [string](Get-PropertyValue $entry 'dispatch_status')
        $am = [string](Get-PropertyValue $entry 'actual_model_id')
        if ($ih -and -not $declared.Contains($ih)) {
            Add-Finding 'ERROR' 'rule-20-intended-handle-drift' (
                "Phase {0} role '{1}': intended_handle '{2}' is not declared in model_assignment or mid_build_overrides. Rule 20 forbids inventing per-phase handles. Declared handles: {3}" -f `
                $phaseIdVal, $role, $ih, (@($declared) -join ', ')
            )
        }
        if ($status -eq 'dispatched-after-override') {
            $matched = $false
            foreach ($o in $overrides) {
                $nh = [string](Get-PropertyValue $o 'new_handle')
                if ($nh -and ($nh -eq $ih -or $nh -eq $am)) { $matched = $true; break }
            }
            if (-not $matched) {
                Add-Finding 'WARN' 'rule-20-orphan-override' (
                    "Phase {0} role '{1}': dispatch_status='dispatched-after-override' but no mid_build_overrides entry references handle '{2}' or model '{3}'." -f `
                    $phaseIdVal, $role, $ih, $am
                )
            }
        }
    }

    # Step 3 — Rule 19 minimum coverage
    $phaseIds = @($log | ForEach-Object { ([string](Get-PropertyValue $_ 'phase_id') -split '-')[0] } | Sort-Object -Unique)
    if ($phaseIds -notcontains '0.0') {
        Add-Finding 'ERROR' 'rule-19-coverage' 'No Phase 0.0 entry in phase_log. Every build must log the model selection result.'
    }
    $hasFactcheck = @($phaseIds | Where-Object { $_ -in @('5.4','6.4','7.0') }).Count -gt 0
    if (-not $hasFactcheck) {
        Add-Finding 'WARN' 'rule-19-coverage' 'No fact-check / audit phase entries (5.4, 6.4, 7.0) in phase_log. Rule 19 cross-phase verification cannot be evaluated.'
    }
    $build52 = @($log | Where-Object { [string](Get-PropertyValue $_ 'phase_id') -eq '5.2' })
    if ($build52.Count -gt 0) {
        $hasA = @($build52 | Where-Object { [string](Get-PropertyValue $_ 'role') -match '(?i)Builder\s*A' }).Count -gt 0
        $hasB = @($build52 | Where-Object { [string](Get-PropertyValue $_ 'role') -match '(?i)Builder\s*B' }).Count -gt 0
        if (-not $hasA) { Add-Finding 'WARN' 'rule-19-build-coverage' 'Phase 5.2 has entries but Builder A did not log any dispatch. Within-phase distinctness check cannot run.' }
        if (-not $hasB) { Add-Finding 'WARN' 'rule-19-build-coverage' 'Phase 5.2 has entries but Builder B did not log any dispatch. Within-phase distinctness check cannot run.' }
    }

    # Step 4 — Registry family lookup
    if ($RegistryPath -and (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
        $regText = Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8
        $registryFamilies = @{}
        # Split into per-handle blocks (each starts with "- handle:") and extract model_id + family
        # by independent regex within the block — registry author may order fields differently.
        $blocks = [regex]::Split($regText, '(?m)^\s*-\s*handle\s*:')
        foreach ($block in $blocks) {
            if ([string]::IsNullOrWhiteSpace($block)) { continue }
            $midMatch = [regex]::Match($block, '(?m)^\s*model_id\s*:\s*([^\r\n]+?)\s*$')
            $famMatch = [regex]::Match($block, '(?m)^\s*family\s*:\s*([^\r\n]+?)\s*$')
            if ($midMatch.Success -and $famMatch.Success) {
                $mid = ($midMatch.Groups[1].Value.Trim() -replace '^["'']|["'']$','')
                $fam = ($famMatch.Groups[1].Value.Trim() -replace '^["'']|["'']$','')
                if ($mid -and $fam) { $registryFamilies[$mid] = $fam }
            }
        }
        foreach ($entry in $log) {
            $mid = [string](Get-PropertyValue $entry 'actual_model_id')
            $fam = ([string](Get-PropertyValue $entry 'actual_family')).ToLowerInvariant()
            if ($registryFamilies.ContainsKey($mid)) {
                $expected = ([string]$registryFamilies[$mid]).ToLowerInvariant()
                if ($expected -ne $fam) {
                    Add-Finding 'ERROR' 'rule-20-family-mismatch' (
                        "Phase {0} role '{1}': actual_family '{2}' does not match registry-declared family '{3}' for model_id '{4}'." -f `
                        (Get-PropertyValue $entry 'phase_id'), (Get-PropertyValue $entry 'role'), $fam, $expected, $mid
                    )
                }
            }
        }
    } else {
        Add-Finding 'INFO' 'registry-skip' 'model-registry.yaml not provided; skipping actual_family cross-check.'
    }

    # Final exit determination
    $errorCount = @($Script:Findings | Where-Object { $_.severity -eq 'ERROR' }).Count
    $warnCount  = @($Script:Findings | Where-Object { $_.severity -eq 'WARN'  }).Count
    if ($errorCount -gt 0) { Emit-Result -Exit 1 }
    if ($Strict -and $warnCount -gt 0) { Emit-Result -Exit 1 }
    Emit-Result -Exit 0

} catch {
    Add-Finding 'ERROR' 'script-error' "Unexpected error: $($_.Exception.Message). $($_.ScriptStackTrace)"
    Emit-Result -Exit 3
}
