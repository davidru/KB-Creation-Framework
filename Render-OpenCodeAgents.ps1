# Title: Render-OpenCodeAgents.ps1 — Render OpenCode static agents from model_assignment.
# Purpose: Generate opencode.json agent entries so OpenCode Task subagents use per-role models.
# Version: 3.1.5 patch for Rule 19 OpenCode static-agent rendering gap.
# Inputs: Optional -AssignmentPath, -OpenCodeJsonPath, -RegistryPath, -OutPath, -DryRun, -Force, -Help.
# Exit codes: 0 rendered; 1 assignment/resolution/write failure; 2 dry-run JSON rendered only.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$AssignmentPath = '',

    [Parameter(Mandatory=$false)]
    [string]$OpenCodeJsonPath = (Join-Path (Get-Location).Path 'opencode.json'),

    [Parameter(Mandatory=$false)]
    [string]$RegistryPath = '',

    [Parameter(Mandatory=$false)]
    [string]$OutPath = '',

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$Script:FrameworkRoot = $PSScriptRoot
$Script:ResolverPath = Join-Path $Script:FrameworkRoot 'Resolve-Model.ps1'
$Script:ResolvedRegistryPath = $null

$Script:RequiredRoles = @(
    'lead',
    'builder_a',
    'builder_b',
    'critic_pool',
    'factcheck_pool_5a_5b_5c',
    'factcheck_pool_5d_5e',
    'factcheck_6b',
    'auditor_7',
    'memo_factcheck_8'
)

$Script:PoolRoles = @('critic_pool','factcheck_pool_5a_5b_5c','factcheck_pool_5d_5e')

$Script:RolePromptMap = @{
    lead = 'prompts\01-orchestrator.md'
    builder_a = 'prompts\13-builder-draft.md'
    builder_b = 'prompts\13-builder-draft.md'
    critic_pool = 'prompts\61-rubber-duck-assembly.md'
    factcheck_pool_5a_5b_5c = 'prompts\51-factcheck-currency.md'
    factcheck_pool_5d_5e = 'prompts\54-factcheck-single-source.md'
    factcheck_6b = 'prompts\64-post-assembly-factcheck.md'
    auditor_7 = 'prompts\70-final-audit.md'
    memo_factcheck_8 = 'prompts\80-downstream-stress-test.md'
}

$Script:RoleDescriptionMap = @{
    lead = 'Lead — orchestrates the KB build.'
    builder_a = 'Builder A — drafts per-topic content.'
    builder_b = 'Builder B — drafts independent per-topic content.'
    critic_pool = 'Critic pool — performs adversarial rubber-duck critique.'
    factcheck_pool_5a_5b_5c = 'Phase 5.1–5.3 fact-check pool — verifies currency, citations, and classification.'
    factcheck_pool_5d_5e = 'Phase 5.4–5.5 fact-check pool — verifies single-source and operative claims.'
    factcheck_6b = 'Phase 6.4 fact-checker — performs post-assembly superset fact-check.'
    auditor_7 = 'Phase 7 auditor — runs final audit and quality scorecard.'
    memo_factcheck_8 = 'Phase 8 memo fact-checker — verifies downstream memo stress tests.'
}

function Show-Usage {
    $usage = @'
Render-OpenCodeAgents.ps1 v3.1.5

Usage:
  pwsh -NoProfile -File .\Render-OpenCodeAgents.ps1 [-AssignmentPath <path>] [-OpenCodeJsonPath <path>] [-RegistryPath <path>] [-OutPath <path>] [-DryRun] [-Force]

Parameters:
  -AssignmentPath     YAML/Markdown file containing model_assignment:. If omitted, prefers .\sources\model_assignment_candidate.yaml, then .\sources\pipeline_state.md.
  -OpenCodeJsonPath  Target opencode.json. Defaults to .\opencode.json in the current KB build directory.
  -RegistryPath      Model registry YAML. Defaults to model-registry.yaml beside this script, with model-registry.example.yaml fallback.
  -OutPath           Optional Markdown summary log path.
  -DryRun            Print rendered JSON only and do not write. Exits 2 by contract.
  -Force             Overwrite existing opencode.json without creating a backup.
  -Help              Print this usage and exit 0.

Pool roles render one OpenCode agent per handle, named <role-kebab>-handle-<n>, so the Lead can dispatch a specific pool member by subagent_type.
'@
    Write-Output $usage
}

function Resolve-AssignmentPath {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).Path }
        throw "AssignmentPath not found: $Path"
    }

    $sources = Join-Path (Get-Location).Path 'sources'
    $candidate = Join-Path $sources 'model_assignment_candidate.yaml'
    $pipeline = Join-Path $sources 'pipeline_state.md'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).Path }
    if (Test-Path -LiteralPath $pipeline -PathType Leaf) { return (Resolve-Path -LiteralPath $pipeline).Path }
    throw "No assignment file found. Provide -AssignmentPath, or create sources\model_assignment_candidate.yaml / sources\pipeline_state.md in the current build directory."
}

function Resolve-RegistryPath {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).Path }
        throw "RegistryPath not found: $Path"
    }

    $local = Join-Path $Script:FrameworkRoot 'model-registry.yaml'
    $example = Join-Path $Script:FrameworkRoot 'model-registry.example.yaml'
    if (Test-Path -LiteralPath $local -PathType Leaf) { return (Resolve-Path -LiteralPath $local).Path }
    if (Test-Path -LiteralPath $example -PathType Leaf) { return (Resolve-Path -LiteralPath $example).Path }
    throw "No model registry found beside the script. Expected model-registry.yaml or model-registry.example.yaml."
}

function Remove-YamlInlineComment {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $inSingle = $false
    $inDouble = $false
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; continue }
        if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; continue }
        if ($ch -eq '#' -and -not $inSingle -and -not $inDouble) {
            if ($i -eq 0 -or [char]::IsWhiteSpace($Text[$i - 1])) { return $Text.Substring(0, $i) }
        }
    }
    return $Text
}

function Unquote-YamlScalar {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    $value = (Remove-YamlInlineComment -Text $Text).Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Split-YamlInlineList {
    param([string]$Text)
    $items = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inSingle = $false
    $inDouble = $false
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; [void]$current.Append($ch); continue }
        if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; [void]$current.Append($ch); continue }
        if ($ch -eq ',' -and -not $inSingle -and -not $inDouble) {
            $items.Add((Unquote-YamlScalar -Text $current.ToString())) | Out-Null
            [void]$current.Clear()
            continue
        }
        [void]$current.Append($ch)
    }
    if ($current.Length -gt 0) { $items.Add((Unquote-YamlScalar -Text $current.ToString())) | Out-Null }
    return @($items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function ConvertFrom-AssignmentYamlValue {
    param([AllowNull()][string]$Text)
    $value = (Remove-YamlInlineComment -Text $Text).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return @() }
    if ($value -match '^\[(.*)\]$') { return @(Split-YamlInlineList -Text $matches[1]) }
    return @((Unquote-YamlScalar -Text $value))
}

function Get-LeadingSpaceCount {
    param([string]$Text)
    if ($Text -match '^(\s*)') { return $matches[1].Length }
    return 0
}

function Read-ModelAssignment {
    param([string]$Path)
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $start = -1
    $baseIndent = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*)model_assignment\s*:\s*(?:#.*)?$') {
            $start = $i
            $baseIndent = $matches[1].Length
            break
        }
    }
    if ($start -lt 0) { throw "No model_assignment: block found in $Path" }

    $assignment = [ordered]@{}
    $childIndent = $null
    $pendingKey = $null

    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        $raw = $lines[$i]
        $trimmed = $raw.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed.StartsWith('```')) {
            if ($assignment.Count -gt 0) { break }
            continue
        }

        $indent = Get-LeadingSpaceCount -Text $raw
        if ($indent -le $baseIndent -and -not ($raw -match '^\s*-\s+')) { break }

        if ($null -ne $pendingKey -and $raw -match '^(\s*)-\s*(.+)$') {
            $listIndent = $matches[1].Length
            if ($null -eq $childIndent -or $listIndent -gt $childIndent) {
                $existing = @($assignment[$pendingKey])
                $assignment[$pendingKey] = @($existing + @((Unquote-YamlScalar -Text $matches[2])))
                continue
            }
        }

        if ($raw -match '^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$') {
            $keyIndent = $matches[1].Length
            $key = $matches[2]
            $valueText = $matches[3]
            if ($keyIndent -le $baseIndent) { break }
            if ($null -eq $childIndent) { $childIndent = $keyIndent }
            if ($keyIndent -ne $childIndent) { continue }

            $values = @(ConvertFrom-AssignmentYamlValue -Text $valueText)
            $assignment[$key] = @($values)
            if ($values.Count -eq 0) { $pendingKey = $key } else { $pendingKey = $null }
        }
    }

    foreach ($role in $Script:RequiredRoles) {
        if (-not $assignment.Contains($role) -or @($assignment[$role]).Count -eq 0) {
            throw "Malformed model_assignment in ${Path}: missing required role '$role' or no handle assigned."
        }
    }
    return $assignment
}

function ConvertTo-AgentName {
    param([string]$Role)
    return ($Role -replace '_','-').ToLowerInvariant()
}

function Get-DispatchFingerprint {
    # v3.1.10 — deterministic dispatch fingerprint for silent-fallback detection.
    # Computed from (agent_name + provider/model_id + opencode-json-path + framework-version).
    # Returned as "DISPATCH-FINGERPRINT::<agent-name>::<16-char-hex>".
    # The agent embeds this in its prompt; the orchestrator reads it from opencode.json's
    # description field and compares against the agent's response. A silent-fallback to the
    # parent model produces a response that lacks the expected fingerprint (parent has no
    # access to the subagent's prompt) — catching the failure at dispatch time, not at
    # Phase 9 scorecard generation.
    param(
        [string]$AgentName,
        [string]$ProviderModelId,
        [string]$OpenCodeJsonPath
    )
    $seed = "{0}|{1}|{2}|v3.1.10" -f $AgentName, $ProviderModelId, ([string]$OpenCodeJsonPath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
    } finally { $sha.Dispose() }
    $hex = -join ($bytes[0..7] | ForEach-Object { $_.ToString('x2') })
    return "DISPATCH-FINGERPRINT::{0}::{1}" -f $AgentName, $hex
}

function Get-RolePromptText {
    param([string]$Role)
    $relative = $Script:RolePromptMap[$Role]
    if ([string]::IsNullOrWhiteSpace($relative)) {
        return "You are the $Role sub-agent in the KB Creation Framework v3.1 pipeline. Receive your task from the parent Lead session."
    }
    $path = Join-Path $Script:FrameworkRoot $relative
    return ('Read `{0}` for your role contract. Receive the concrete task, inputs, and output path from the parent Lead session.' -f $path)
}

function Get-AgentPermission {
    param([string]$Role)
    if ($Role -eq 'auditor_7' -or $Role -like 'factcheck_*' -or $Role -eq 'memo_factcheck_8') {
        return [ordered]@{
            read = 'allow'
            glob = 'allow'
            grep = 'allow'
            bash = 'allow'
            edit = 'deny'
            write = 'deny'
            task = 'deny'
        }
    }
    return [ordered]@{}
}

function Resolve-HandleForRender {
    param([string]$Handle)
    if (-not (Test-Path -LiteralPath $Script:ResolverPath -PathType Leaf)) {
        throw "Resolve-Model.ps1 not found at $Script:ResolverPath"
    }

    $output = @(& $Script:ResolverPath -Handle $Handle -RegistryPath $Script:ResolvedRegistryPath 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $message = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
        throw "Resolve-Model.ps1 failed for handle '$Handle' (exit $exitCode): $message"
    }

    $resolved = @($output | Where-Object { $_ -is [System.Collections.IDictionary] } | Select-Object -First 1)
    if ($resolved.Count -eq 0) { throw "Resolve-Model.ps1 returned no structured object for handle '$Handle'." }
    $data = $resolved[0]

    foreach ($field in @('provider','model_id','family')) {
        if ([string]::IsNullOrWhiteSpace([string]$data[$field])) {
            throw "Resolve-Model.ps1 result for handle '$Handle' is missing '$field'."
        }
    }

    $adapter = Join-Path $Script:FrameworkRoot (Join-Path 'adapters\model-providers' ([string]$data['provider']))
    return [pscustomobject]([ordered]@{
        handle = [string]$data['handle']
        provider = [string]$data['provider']
        model_id = [string]$data['model_id']
        family = [string]$data['family']
        adapter_path = $adapter
    })
}

function New-AgentEntry {
    param(
        [string]$Role,
        [string]$AgentName,
        $Resolved,
        [string]$OpenCodeJsonPath
    )

    $roleDescription = $Script:RoleDescriptionMap[$Role]
    if ([string]::IsNullOrWhiteSpace($roleDescription)) { $roleDescription = "$Role framework role." }

    $providerModel = "$($Resolved.provider)/$($Resolved.model_id)"
    $fingerprint = Get-DispatchFingerprint -AgentName $AgentName -ProviderModelId $providerModel -OpenCodeJsonPath $OpenCodeJsonPath

    # Embed fingerprint in BOTH description (orchestrator extracts via regex) and prompt (agent echoes it).
    # The fingerprint in the prompt is what makes silent-fallback detectable: a subagent that's actually
    # dispatched has the prompt and can echo it; a parent-model fallback doesn't have access to the
    # subagent's prompt and cannot produce the expected fingerprint.
    $basePrompt = Get-RolePromptText -Role $Role
    $promptWithFp = @"
$basePrompt

DISPATCH FINGERPRINT (Rule 20 / v3.1.10):
When the orchestrator's first message to you contains the token ``ECHO-FINGERPRINT``, your response MUST start (first non-empty line) with exactly this string, then a blank line, then your normal task output:

$fingerprint

If the orchestrator omits ``ECHO-FINGERPRINT``, proceed normally without prefixing the fingerprint. This mechanism lets the orchestrator detect silent-fallback to the parent model: a parent-model fallback cannot see this prompt and cannot produce the fingerprint.
"@

    return [ordered]@{
        description = "Framework role: $roleDescription Model family: $($Resolved.family). [FP: $fingerprint]"
        model = $providerModel
        mode = $(if ($Role -eq 'lead') { 'primary' } else { 'subagent' })
        prompt = $promptWithFp
        permission = (Get-AgentPermission -Role $Role)
    }
}

function Convert-AssignmentToConfig {
    param($Assignment, [string]$OpenCodeJsonPath)
    $agents = [ordered]@{}
    $summary = New-Object System.Collections.Generic.List[object]

    foreach ($role in $Script:RequiredRoles) {
        $handles = @($Assignment[$role])
        for ($i = 0; $i -lt $handles.Count; $i++) {
            $handle = [string]$handles[$i]
            $resolved = Resolve-HandleForRender -Handle $handle
            $baseName = ConvertTo-AgentName -Role $role
            $agentName = if ($role -in $Script:PoolRoles) { "$baseName-handle-$($i + 1)" } else { $baseName }

            if ($agents.Contains($agentName)) { throw "Duplicate OpenCode agent name generated: $agentName" }
            $agents[$agentName] = New-AgentEntry -Role $role -AgentName $agentName -Resolved $resolved -OpenCodeJsonPath $OpenCodeJsonPath
            $summary.Add([pscustomobject]([ordered]@{
                role = $role
                agent = $agentName
                handle = $handle
                provider_model = "$($resolved.provider)/$($resolved.model_id)"
                family = $resolved.family
                adapter_path = $resolved.adapter_path
            })) | Out-Null
        }
    }

    if ($agents.Contains('lead')) {
        $taskPermissions = [ordered]@{ '*' = 'deny' }
        foreach ($name in $agents.Keys) {
            if ($name -ne 'lead') { $taskPermissions[$name] = 'allow' }
        }
        $agents['lead']['permission'] = [ordered]@{ task = $taskPermissions }

        # v3.1.10 — Inject the dispatch routing map into the Lead's prompt so the orchestrator
        # knows the EXACT subagent names to dispatch to (not registry handle names) and the
        # expected dispatch fingerprint per subagent (for silent-fallback detection).
        $routingLines = New-Object System.Collections.Generic.List[string]
        $routingLines.Add('') | Out-Null
        $routingLines.Add('---') | Out-Null
        $routingLines.Add('') | Out-Null
        $routingLines.Add('## DISPATCH ROUTING TABLE (v3.1.10, generated by Render-OpenCodeAgents.ps1)') | Out-Null
        $routingLines.Add('') | Out-Null
        $routingLines.Add('When you (Lead) invoke the Task tool, the `subagent_type` parameter MUST be one of these exact names. Registry handle names (e.g. `lead-xai-grok43`, `builder-deepseek-v4-flash`, `factcheck-deepseek`) are NOT valid `subagent_type` values — OpenCode will silently fall back to your own model. The mapping below is the ONLY authoritative source.') | Out-Null
        $routingLines.Add('') | Out-Null
        $routingLines.Add('| Framework role | OpenCode subagent name (use this as `subagent_type`) | Configured model | Expected DISPATCH-FINGERPRINT |') | Out-Null
        $routingLines.Add('|---|---|---|---|') | Out-Null
        foreach ($s in $summary) {
            $agent = $agents[$s.agent]
            $fpMatch = [regex]::Match([string]$agent.description, 'DISPATCH-FINGERPRINT::[^\s\]]+::[0-9a-f]+')
            $fp = if ($fpMatch.Success) { $fpMatch.Value } else { '(missing — re-render)' }
            $routingLines.Add("| $($s.role) | ``$($s.agent)`` | $($s.provider_model) | ``$fp`` |") | Out-Null
        }
        $routingLines.Add('') | Out-Null
        $routingLines.Add('### Dispatch protocol (MANDATORY)') | Out-Null
        $routingLines.Add('') | Out-Null
        $routingLines.Add('Every Task dispatch you make MUST follow this protocol:') | Out-Null
        $routingLines.Add('') | Out-Null
        $routingLines.Add('1. Look up the target framework role in the table above; use the exact `subagent_type` from the second column.') | Out-Null
        $routingLines.Add('2. Prepend the literal token `ECHO-FINGERPRINT` to your task prompt (on its own first line or as the first word). Example: `ECHO-FINGERPRINT\n\nDraft topic 3 (formation requirements) per these inputs: ...`') | Out-Null
        $routingLines.Add('3. After dispatch, inspect the response: it MUST begin (first non-empty line) with the Expected DISPATCH-FINGERPRINT for that subagent.') | Out-Null
        $routingLines.Add('4. If the fingerprint matches: log `dispatch_status: dispatched-as-intended` in `sources/pipeline_state.md`, then use the response.') | Out-Null
        $routingLines.Add('5. If the fingerprint does NOT match (or is absent): this is a silent-fallback to the parent model. Per DISPATCH-FAILURE CONTRACT (above), STOP the affected phase, log `dispatch_status: dispatched-with-substitution` with notes detailing the mismatch, and surface the failure to the operator with the three explicit choices (investigate-and-fix / acknowledged-Rule-19-opt-out / abort). Do NOT use the response as if dispatch succeeded.') | Out-Null
        $routingLines.Add('') | Out-Null
        $routingLines.Add('You can verify a response mechanically with: `pwsh "<framework-root>\Test-DispatchFingerprint.ps1" -OpenCodeJsonPath ".\opencode.json" -AgentName "<subagent>" -ResponseText "<first 200 chars of response>"`. The script returns exit code 0 on match, 1 on mismatch.') | Out-Null

        $existingPrompt = [string]$agents['lead']['prompt']
        $agents['lead']['prompt'] = $existingPrompt + ([Environment]::NewLine + ($routingLines -join [Environment]::NewLine))
    }

    $config = [ordered]@{
        '$schema' = 'https://opencode.ai/config.json'
        shell = 'pwsh'
        agent = $agents
    }

    return [pscustomobject]([ordered]@{
        config = $config
        summary = @($summary.ToArray())
    })
}

function Write-RenderedJson {
    param([string]$Path, [string]$Json)
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent)) { $parent = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $backup = ''
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if (-not $Force) {
            $directory = Split-Path -Parent $Path
            if ([string]::IsNullOrWhiteSpace($directory)) { $directory = (Get-Location).Path }
            $leaf = Split-Path -Leaf $Path
            $stem = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
            $extension = [System.IO.Path]::GetExtension($leaf)
            $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
            $backup = Join-Path $directory "$stem.backup-$timestamp$extension"
            Copy-Item -LiteralPath $Path -Destination $backup -Force
        }
    }

    Set-Content -LiteralPath $Path -Value $Json -Encoding UTF8
    return $backup
}

function Format-RenderSummary {
    param(
        [string]$AssignmentFile,
        [string]$RegistryFile,
        [string]$TargetFile,
        [AllowNull()][string]$BackupFile,
        [array]$Rows
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Render-OpenCodeAgents summary') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add(('- Assignment: `{0}`' -f $AssignmentFile)) | Out-Null
    $lines.Add(('- Registry: `{0}`' -f $RegistryFile)) | Out-Null
    $lines.Add(('- Output: `{0}`' -f $TargetFile)) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($BackupFile)) { $lines.Add(('- Backup created: `{0}`' -f $BackupFile)) | Out-Null }
    $lines.Add('') | Out-Null
    $lines.Add('| Role | Agent | Handle | Provider/model_id | Family |') | Out-Null
    $lines.Add('|---|---|---|---|---|') | Out-Null
    foreach ($row in $Rows) {
        $lines.Add("| $($row.role) | $($row.agent) | $($row.handle) | $($row.provider_model) | $($row.family) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('**You must restart OpenCode for these changes to take effect — OpenCode loads config at startup, not hot-reload (per HOST-NOTES §7.)**') | Out-Null
    return ($lines -join [Environment]::NewLine)
}

try {
    if ($Help) { Show-Usage; exit 0 }

    $resolvedAssignmentPath = Resolve-AssignmentPath -Path $AssignmentPath
    $Script:ResolvedRegistryPath = Resolve-RegistryPath -Path $RegistryPath
    $resolvedOpenCodeJsonPath = $OpenCodeJsonPath
    if (-not [System.IO.Path]::IsPathRooted($resolvedOpenCodeJsonPath)) {
        $resolvedOpenCodeJsonPath = Join-Path (Get-Location).Path $resolvedOpenCodeJsonPath
    }

    $assignment = Read-ModelAssignment -Path $resolvedAssignmentPath
    $rendered = Convert-AssignmentToConfig -Assignment $assignment -OpenCodeJsonPath $resolvedOpenCodeJsonPath
    $json = $rendered.config | ConvertTo-Json -Depth 20

    if ($DryRun) {
        Write-Output $json
        exit 2
    }

    $backupPath = Write-RenderedJson -Path $resolvedOpenCodeJsonPath -Json $json
    $summaryText = Format-RenderSummary -AssignmentFile $resolvedAssignmentPath -RegistryFile $Script:ResolvedRegistryPath -TargetFile $resolvedOpenCodeJsonPath -BackupFile $backupPath -Rows $rendered.summary
    if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
        $outParent = Split-Path -Parent $OutPath
        if (-not [string]::IsNullOrWhiteSpace($outParent) -and -not (Test-Path -LiteralPath $outParent -PathType Container)) {
            New-Item -ItemType Directory -Path $outParent -Force | Out-Null
        }
        Set-Content -LiteralPath $OutPath -Value $summaryText -Encoding UTF8
    }
    Write-Output $summaryText
    exit 0
} catch {
    $errorMessage = [string]$_.Exception.Message
    if (-not [string]::IsNullOrWhiteSpace($_.ScriptStackTrace)) {
        $errorMessage = $errorMessage + [Environment]::NewLine + $_.ScriptStackTrace
    }
    Write-Error -Message $errorMessage
    exit 1
}
