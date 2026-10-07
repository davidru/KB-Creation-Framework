<#
.SYNOPSIS
    Validate-ModelAssignment.ps1 — v3 Phase 0.0 model-family separation validator.

.DESCRIPTION
    Validates an operator's model assignment YAML against Rule 19 (Model-Family
    Separation) invariants before a KB v3 build begins. The script is fully
    mechanical: it parses the narrow assignment YAML schema, resolves registry
    handles through Resolve-Model.ps1, reads family declarations from the Model
    Registry, emits a Markdown validation report, and exits with a deterministic
    PASS / WARN / BLOCK code.

.PARAMETER AssignmentPath
    Path to the YAML model assignment file.

.PARAMETER OutPath
    Path to write the Markdown validation report.

.PARAMETER RegistryPath
    Path to the Model Registry file. Defaults to model-registry.yaml; Resolve-Model.ps1
    falls back to model-registry.example.yaml when the local registry is absent.

.PARAMETER Acknowledge
    Records an explicit operator acknowledgment of Rule 19 family-separation
    violations. Acknowledged Rule 19 violations return WARN (exit 1) instead of
    BLOCK (exit 2). Unknown/unreachable handles remain BLOCKING.

.EXITCODES
    0 = PASS / no violations.
    1 = WARN / Rule 19 violations present and acknowledged.
    2 = BLOCK / unacknowledged Rule 19 violation, missing rationale, malformed
        assignment, or unknown/unreachable model handle.

.RELATED
    KB Creation - Modular v3\01-shared-axioms.md — Rule 19 Model-Family Separation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AssignmentPath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [Parameter(Mandatory=$false)][string]$RegistryPath = (Join-Path $PSScriptRoot 'model-registry.yaml'),
    [switch]$Acknowledge
)

$ErrorActionPreference = 'Stop'
$resolutionCache = @{}

function ConvertTo-SimpleAssignmentYaml {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "AssignmentPath not found: $Path" }

    $result = @{}
    $contentItems = Get-Content -LiteralPath $Path
    $lines = foreach ($item in $contentItems) { [string]$item -split "`r?`n" }
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([A-Za-z0-9_\-]+):\s*(.*)$') { continue }
        $key = $matches[1]
        $value = $matches[2].Trim()
        if ($key -eq 'model_assignment' -and [string]::IsNullOrWhiteSpace($value)) { continue }
        if ($value -match '^\[(.*)\]$') {
            $inner = $matches[1]
            $items = @()
            if ($inner.Trim()) {
                $items = @($inner -split ',' | ForEach-Object { ($_.Trim() -replace '^[''\"]|[''\"]$','') } | Where-Object { $_ })
            }
            $result[$key] = $items
        } else {
            $result[$key] = ($value -replace '^[''\"]|[''\"]$','')
        }
    }
    return $result
}

function ConvertTo-PSQuotedString {
    param([string]$Text)
    return "'" + ($Text -replace "'", "''") + "'"
}

function Resolve-ModelHandle {
    param([string]$Handle)
    if ([string]::IsNullOrWhiteSpace($Handle)) { throw 'Model Registry handle is empty.' }
    if ($resolutionCache.ContainsKey($Handle)) { return $resolutionCache[$Handle] }

    $resolver = Join-Path $PSScriptRoot 'Resolve-Model.ps1'
    if (-not (Test-Path -LiteralPath $resolver)) { throw "Resolve-Model.ps1 not found at $resolver" }

    $command = "& $((ConvertTo-PSQuotedString $resolver)) -Handle $((ConvertTo-PSQuotedString $Handle)) -RegistryPath $((ConvertTo-PSQuotedString $RegistryPath)) | ConvertTo-Json -Depth 10"
    $output = & pwsh -NoProfile -Command $command 2>&1
    $resolverExit = $LASTEXITCODE
    $outputLines = @($output | ForEach-Object { [string]$_ })
    $outputText = ($outputLines -join "`n").Trim()

    if ($resolverExit -ne 0) {
        throw "Resolve-Model.ps1 failed for handle '$Handle': $outputText"
    }

    $jsonStart = -1
    for ($i = 0; $i -lt $outputLines.Count; $i++) {
        if ($outputLines[$i].TrimStart().StartsWith('{')) { $jsonStart = $i; break }
    }
    if ($jsonStart -lt 0) {
        throw "Resolve-Model.ps1 returned no JSON for handle '$Handle': $outputText"
    }

    $json = ($outputLines[$jsonStart..($outputLines.Count - 1)] -join "`n")
    try {
        $resolved = $json | ConvertFrom-Json
    } catch {
        throw "Resolve-Model.ps1 returned malformed JSON for handle '$Handle': $($_.Exception.Message)"
    }

    if ([string]::IsNullOrWhiteSpace([string]$resolved.family)) {
        throw "Resolved registry entry for handle '$Handle' has no family declaration."
    }

    $resolutionCache[$Handle] = $resolved
    return $resolved
}

function Get-ModelsForRole {
    param([hashtable]$Assignment, [string]$Role)
    if (-not $Assignment.ContainsKey($Role)) { return @() }
    $value = $Assignment[$Role]
    if ($value -is [System.Array]) { return @($value | Where-Object { $_ }) }
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return @() }
    return @([string]$value)
}

function Get-ModelFamily {
    param([string]$Handle)
    try {
        $resolved = Resolve-ModelHandle -Handle $Handle
        return [string]$resolved.family
    } catch {
        return 'Unknown'
    }
}

function Get-ResolvedModelDisplay {
    param([string]$Handle)
    try {
        $resolved = Resolve-ModelHandle -Handle $Handle
        return ("{0}/{1}" -f $resolved.provider, $resolved.model_id)
    } catch {
        return 'Unresolved'
    }
}

function Get-FamiliesForRole {
    param([hashtable]$Assignment, [string]$Role)
    return @(Get-ModelsForRole -Assignment $Assignment -Role $Role | ForEach-Object { Get-ModelFamily $_ } | Select-Object -Unique)
}

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ')
}

$assignment = $null
$violations = New-Object System.Collections.Generic.List[psobject]
$hardFailures = New-Object System.Collections.Generic.List[psobject]

try {
    $assignment = ConvertTo-SimpleAssignmentYaml -Path $AssignmentPath
} catch {
    $hardFailures.Add([pscustomobject]@{ Rule='schema'; Phases='Phase 0.0'; Conflict=$_.Exception.Message; Resolution='Fix YAML path/schema and rerun.' }) | Out-Null
    $assignment = @{}
}

$required = @('preset','lead','builder_a','builder_b','critic_pool','factcheck_pool_5a_5b_5c','factcheck_pool_5d_5e','factcheck_6b','auditor_7','memo_factcheck_8','rule_19_opt_out')
foreach ($key in $required) {
    if (-not $assignment.ContainsKey($key) -or @(Get-ModelsForRole -Assignment $assignment -Role $key).Count -eq 0) {
        $hardFailures.Add([pscustomobject]@{ Rule='schema'; Phases='Phase 0.0'; Conflict="Missing required assignment key: $key"; Resolution='Populate the required key and rerun.' }) | Out-Null
    }
}

foreach ($role in $required | Where-Object { $_ -notin @('preset','rule_19_opt_out') }) {
    foreach ($handle in Get-ModelsForRole -Assignment $assignment -Role $role) {
        try {
            $resolved = Resolve-ModelHandle -Handle $handle
            if ([string]::IsNullOrWhiteSpace([string]$resolved.family)) {
                $hardFailures.Add([pscustomobject]@{ Rule='model-registry'; Phases=$role; Conflict="Handle '$handle' resolves without a registry family declaration."; Resolution='Add family to the registry entry and rerun.' }) | Out-Null
            }
        } catch {
            $hardFailures.Add([pscustomobject]@{ Rule='model-availability'; Phases=$role; Conflict="Handle '$handle' is not resolvable through Resolve-Model.ps1 / Model Registry. $($_.Exception.Message)"; Resolution='Choose a handle present in model-registry.yaml/model-registry.example.yaml or update the registry.' }) | Out-Null
        }
    }
}
function Add-SeparationViolation {
    param([string]$Rule, [string]$Phases, [string]$Conflict, [string]$Resolution)
    $violations.Add([pscustomobject]@{ Rule=$Rule; Phases=$Phases; Conflict=$Conflict; Resolution=$Resolution }) | Out-Null
}

function Assert-RoleFamiliesDifferent {
    param([string]$Left, [string]$Right, [string]$RuleText)
    $lf = @(Get-FamiliesForRole -Assignment $assignment -Role $Left | Where-Object { $_ -ne 'Unknown' })
    $rf = @(Get-FamiliesForRole -Assignment $assignment -Role $Right | Where-Object { $_ -ne 'Unknown' })
    foreach ($f in $lf) {
        if ($rf -contains $f) {
            Add-SeparationViolation -Rule $RuleText -Phases "$Left / $Right" -Conflict "Both roles include registry family $f." -Resolution 'Select a replacement handle from a different registry family, or rerun with -Acknowledge and an opt_out_rationale.'
        }
    }
}

function Assert-PoolDifferentFromRoles {
    param([string]$PoolRole, [string[]]$OtherRoles, [string]$RuleText)
    $poolFamilies = @(Get-FamiliesForRole -Assignment $assignment -Role $PoolRole | Where-Object { $_ -ne 'Unknown' })
    foreach ($other in $OtherRoles) {
        $otherFamilies = @(Get-FamiliesForRole -Assignment $assignment -Role $other | Where-Object { $_ -ne 'Unknown' })
        foreach ($f in $poolFamilies) {
            if ($otherFamilies -contains $f) {
                Add-SeparationViolation -Rule $RuleText -Phases "$PoolRole / $other" -Conflict "$PoolRole includes registry family $f, also used by $other." -Resolution 'Move one phase/pool to a different registry family, or acknowledge Rule 19 opt-out.'
            }
        }
    }
}

if ($hardFailures.Count -eq 0) {
    Assert-RoleFamiliesDifferent -Left 'lead' -Right 'builder_a' -RuleText 'Lead, Builder A, and Builder B must be different families.'
    Assert-RoleFamiliesDifferent -Left 'lead' -Right 'builder_b' -RuleText 'Lead, Builder A, and Builder B must be different families.'
    Assert-RoleFamiliesDifferent -Left 'builder_a' -Right 'builder_b' -RuleText 'Lead, Builder A, and Builder B must be different families.'
    Assert-PoolDifferentFromRoles -PoolRole 'critic_pool' -OtherRoles @('lead','builder_a','builder_b') -RuleText 'Critic pool must be different family from Lead and Builders.'
    Assert-RoleFamiliesDifferent -Left 'factcheck_pool_5d_5e' -Right 'factcheck_pool_5a_5b_5c' -RuleText 'Phase 5d/5e fact-check pool must differ from Phase 5a/5b/5c pool.'
    Assert-RoleFamiliesDifferent -Left 'factcheck_6b' -Right 'factcheck_pool_5a_5b_5c' -RuleText 'Phase 6b must differ from Phase 5b family.'
    Assert-PoolDifferentFromRoles -PoolRole 'auditor_7' -OtherRoles @('factcheck_6b','factcheck_pool_5a_5b_5c') -RuleText 'Phase 7 auditor must differ from Phase 6b and Phase 5b.'
    Assert-RoleFamiliesDifferent -Left 'memo_factcheck_8' -Right 'factcheck_6b' -RuleText 'Phase 8 memo fact-check must differ from Phase 6b.'
}

$preset = if ($assignment.ContainsKey('preset')) { [string]$assignment['preset'] } else { '' }
$rationale = if ($assignment.ContainsKey('opt_out_rationale')) { [string]$assignment['opt_out_rationale'] } else { '' }
$rule19OptOut = if ($assignment.ContainsKey('rule_19_opt_out')) { [string]$assignment['rule_19_opt_out'] } else { '' }
$requiresRationale = ($rule19OptOut -eq 'required') -or ($violations.Count -gt 0)
if ($requiresRationale -and $Acknowledge -and [string]::IsNullOrWhiteSpace($rationale)) {
    $hardFailures.Add([pscustomobject]@{ Rule='opt-out-rationale'; Phases='Phase 0.0'; Conflict='Rule 19 opt-out was acknowledged but opt_out_rationale is empty.'; Resolution='Add opt_out_rationale to the assignment YAML.' }) | Out-Null
}

$verdict = 'PASS'
$exitCode = 0
if ($hardFailures.Count -gt 0) {
    $verdict = 'BLOCK'
    $exitCode = 2
} elseif ($violations.Count -gt 0 -and $Acknowledge) {
    $verdict = 'WARN (with acknowledgment)'
    $exitCode = 1
} elseif ($violations.Count -gt 0) {
    $verdict = 'BLOCK'
    $exitCode = 2
}

$familiesRows = foreach ($role in @('lead','builder_a','builder_b','critic_pool','factcheck_pool_5a_5b_5c','factcheck_pool_5d_5e','factcheck_6b','auditor_7','memo_factcheck_8')) {
    $handles = @(Get-ModelsForRole -Assignment $assignment -Role $role)
    if ($handles.Count -gt 0) {
        $families = @($handles | ForEach-Object { Get-ModelFamily $_ } | Select-Object -Unique)
        $resolvedModels = @($handles | ForEach-Object { Get-ResolvedModelDisplay $_ })
        "| $role | $(Escape-Md ($handles -join ', ')) | $(Escape-Md ($families -join ', ')) | $(Escape-Md ($resolvedModels -join ', ')) |"
    }
}

$report = New-Object System.Collections.Generic.List[string]
$report.Add('# Model Assignment Validation Report') | Out-Null
$report.Add('') | Out-Null
$report.Add("- Assignment path: ``$AssignmentPath``") | Out-Null
$report.Add("- Registry path: ``$RegistryPath``") | Out-Null
$report.Add('- Family source: Model Registry entries resolved through `Resolve-Model.ps1`.') | Out-Null
$report.Add("- Run timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$report.Add("- Acknowledgment switch present: **$($Acknowledge.IsPresent)**") | Out-Null
$report.Add('') | Out-Null
$report.Add("## VERDICT: **$verdict**") | Out-Null
$report.Add('') | Out-Null
$report.Add('## Role family map') | Out-Null
$report.Add('') | Out-Null
$report.Add('| Role | Registry handle(s) | Registry family/families | Resolved provider/model_id |') | Out-Null
$report.Add('|---|---|---|---|') | Out-Null
foreach ($row in $familiesRows) { $report.Add($row) | Out-Null }
$report.Add('') | Out-Null

$allFindings = @($hardFailures) + @($violations)
if ($allFindings.Count -gt 0) {
    $report.Add('## Violations') | Out-Null
    $report.Add('') | Out-Null
    $report.Add('| Rule | Phase(s) | Conflict | Resolution |') | Out-Null
    $report.Add('|---|---|---|---|') | Out-Null
    foreach ($v in $allFindings) {
        $report.Add("| $(Escape-Md $v.Rule) | $(Escape-Md $v.Phases) | $(Escape-Md $v.Conflict) | $(Escape-Md $v.Resolution) |") | Out-Null
    }
    $report.Add('') | Out-Null
} else {
    $report.Add('## Violations') | Out-Null
    $report.Add('') | Out-Null
    $report.Add('_None._') | Out-Null
    $report.Add('') | Out-Null
}

if ($requiresRationale -or $allFindings.Count -gt 0) {
    $report.Add('## Opt-out rationale') | Out-Null
    $report.Add('') | Out-Null
    if ([string]::IsNullOrWhiteSpace($rationale)) {
        $report.Add('_No rationale supplied._') | Out-Null
    } else {
        $report.Add('```text') | Out-Null
        $report.Add($rationale) | Out-Null
        $report.Add('```') | Out-Null
    }
    $report.Add('') | Out-Null
}

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$report -join "`n" | Set-Content -LiteralPath $OutPath

Write-Host "Model assignment validation: $verdict — report at $OutPath"
exit $exitCode
