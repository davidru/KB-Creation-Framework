<#
.SYNOPSIS
    Migrate-V2KBtoV3.ps1 — opt-in v2 KB to v3 quality-artifact migration, plus v3.0 to v3.1 model-registry migration support.

.DESCRIPTION
    Mechanically upgrades a v2-built KB to v3 quality artifacts without model
    invocation. Validates the v2 KB shape, archives the existing authority/ view,
    regenerates practice/ and authority/, synthesizes v3 manifests for VOLATILE
    and unresolved verification tags, runs the KB Quality Scorecard, and writes a
    migration report.

    Also migrates v3.0 model_assignment blocks to v3.1 Model Registry handles by
    synthesizing model-registry.yaml at the operator framework root and rewriting
    sources/scoping_report.md and sources/pipeline_state.md to use those handles.

.PARAMETER KBRoot
    Absolute path to the KB root. Required unless -Help is used.

.PARAMETER DryRun
    Reports what would be migrated without writing files or invoking generators.

.PARAMETER Force
    Allows overwriting existing migration artifacts from a prior or partial run.

.PARAMETER FromVersion
    Optional source version override. Allowed values: v2, v3.0. If omitted, the
    script auto-detects v2 when no model_assignment block is found, v3.0 when
    model_assignment exists but model-registry.yaml is absent at the framework root,
    and refuses already-registry-backed v3.1 inputs unless -FromVersion is explicit.

.PARAMETER Help
    Prints usage help and exits.

.EXITCODES
    0 = fully migrated, no migration caveats.
    1 = migrated with caveats, including build-incomplete scorecard, extraction failures, or hand-edit-required model family values.
    2 = cannot migrate: unrecognizable source KB or existing migration artifacts without -Force.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$KBRoot,
    [switch]$DryRun,
    [switch]$Force,
    [string]$FromVersion,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = 'v3.1.0-pre migration script 2026-06-06'
$ScriptDir = Split-Path -Parent $PSCommandPath

function Show-Help {
    Write-Host @"
Migrate-V2KBtoV3.ps1

Usage:
  pwsh .\Migrate-V2KBtoV3.ps1 -KBRoot <path> [-FromVersion v2|v3.0] [-DryRun] [-Force]
  pwsh .\Migrate-V2KBtoV3.ps1 -Help

Parameters:
  -KBRoot       Absolute path to the KB root. Required unless -Help is used.
  -FromVersion  Source version override: v2 or v3.0. Omit to auto-detect.
                Auto-detect selects v2 when no model_assignment block is found,
                v3.0 when model_assignment exists and model-registry.yaml is
                absent at this framework root, and refuses already-registry-backed
                v3.1 inputs unless -FromVersion is explicit.
  -DryRun       Report planned writes without changing files.
  -Force        Overwrite existing migration artifacts where supported.
  -Help         Print this help and exit.

v2 path:
  Archives authority/, regenerates practice/ and authority/, synthesizes v3
  manifests, runs the KB Quality Scorecard, and writes audit/v2-to-v3-migration.md.

v3.0 path:
  Synthesizes model-registry.yaml at the framework root, rewrites legacy raw
  model IDs in sources/scoping_report.md and sources/pipeline_state.md to registry
  handles, and writes audit/v3.0-to-v3.1-migration.md.
"@
}

function Exit-Script {
    param([int]$Code)
    $host.SetShouldExit($Code)
    exit $Code
}

function Escape-Md {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace '\|','\|') -replace "`r?`n", ' ').Trim()
}

function Write-CannotMigrate {
    param([string]$Message)
    [Console]::Error.WriteLine("Cannot migrate: not a recognizable v2 KB. $Message")
}

function Get-MarkdownAnchor {
    param([string]$Heading)
    $text = ($Heading -replace '^\s*#{1,6}\s*','').Trim().ToLowerInvariant()
    $text = $text -replace '[^a-z0-9\s-]',''
    $text = ($text -replace '\s+','-').Trim('-')
    if (-not $text) { return $null }
    return "#$text"
}

function Get-NearestHeadingAnchor {
    param([string[]]$Lines, [int]$Index)
    for ($i = $Index; $i -ge 0; $i--) {
        if ($Lines[$i] -match '^\s*#{1,6}\s+') { return Get-MarkdownAnchor $Lines[$i] }
    }
    return $null
}

function Get-ParagraphAtLine {
    param([string[]]$Lines, [int]$Index)
    if ($Lines.Count -eq 0) { return '' }
    $start = $Index
    while ($start -gt 0 -and $Lines[$start - 1] -notmatch '^\s*$' -and $Lines[$start - 1] -notmatch '^\s*#{1,6}\s+') { $start-- }
    $end = $Index
    while ($end -lt ($Lines.Count - 1) -and $Lines[$end + 1] -notmatch '^\s*$' -and $Lines[$end + 1] -notmatch '^\s*#{1,6}\s+') { $end++ }
    return (($Lines[$start..$end] -join ' ') -replace '\s+', ' ').Trim()
}

function Remove-KnownTags {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $clean = $Text
    $clean = $clean -replace '<!--\s*\[(GUIDANCE|INTERPRETATION|UNVERIFIED|NEEDS-VERIFICATION|VOLATILE:[^\]]+)\]\s*-->',' '
    $clean = $clean -replace '\[(GUIDANCE|INTERPRETATION|UNVERIFIED|NEEDS-VERIFICATION|VOLATILE:[^\]]+)\]',' '
    $clean = $clean -replace '^\s*#{1,6}\s*',''
    return ($clean -replace '\s+', ' ').Trim()
}

function Get-FirstSentence {
    param([string]$Text)
    $clean = Remove-KnownTags $Text
    if (-not $clean) { return '' }
    $m = [regex]::Match($clean, '^(.{20,}?[.!?])(?:\s|$)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    if ($clean.Length -gt 240) { return ($clean.Substring(0, 240).Trim() + ' …') }
    return $clean
}

function Get-ClaimText {
    param([string[]]$Lines, [int]$Index)
    return Get-FirstSentence (Get-ParagraphAtLine -Lines $Lines -Index $Index)
}

function Get-NearbyAsOfDate {
    param([string[]]$Lines, [int]$Index)
    $start = [math]::Max(0, $Index - 3)
    $end = [math]::Min($Lines.Count - 1, $Index + 3)
    for ($i = $start; $i -le $end; $i++) {
        $m = [regex]::Match($Lines[$i], '(?i)\[?\s*as\s+of\s+(\d{4}-\d{2}-\d{2})\s*\]?')
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return 'null'
}

function Get-BestEffortCurrentValue {
    param([string]$ClaimText)
    $patterns = @(
        '(?:\$|€|£)\s?\d{1,3}(?:,\d{3})*(?:\.\d+)?',
        '\b\d{4}-\d{2}-\d{2}\b',
        '(?i)\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}\b',
        '\b\d{1,3}(?:,\d{3})*(?:\.\d+)?\s?(?:%|percent|days?|months?|years?|hours?|units?|USD|EUR|GBP)\b'
    )
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $patterns) {
        foreach ($m in [regex]::Matches($ClaimText, $pattern)) {
            if (-not $hits.Contains($m.Value.Trim())) { $hits.Add($m.Value.Trim()) | Out-Null }
        }
    }
    if ($hits.Count -gt 0) { return (($hits | Select-Object -First 3) -join '; ') }
    return 'operator-review-required'
}

function Get-ViewRetention {
    param([System.IO.FileInfo[]]$FullFiles, [string]$ViewDir)
    if (-not (Test-Path -LiteralPath $ViewDir)) {
        return [pscustomobject]@{ Present=$false; Files=0; Ratio=$null; FullBytes=0; ViewBytes=0 }
    }
    [int64]$fullBytes = 0
    [int64]$viewBytes = 0
    $peerCount = 0
    foreach ($file in $FullFiles) {
        $fullBytes += $file.Length
        $peer = Join-Path $ViewDir $file.Name
        if (Test-Path -LiteralPath $peer) {
            $peerCount++
            $viewBytes += (Get-Item -LiteralPath $peer).Length
        }
    }
    $ratio = if ($fullBytes -gt 0) { [math]::Round(($viewBytes / $fullBytes) * 100, 1) } else { 0 }
    return [pscustomobject]@{ Present=$true; Files=$peerCount; Ratio=$ratio; FullBytes=$fullBytes; ViewBytes=$viewBytes }
}

function Get-ExistingV3Artifacts {
    param([string]$Root)
    $candidates = @(
        'practice',
        'authority.v2-archive',
        'sources\volatile_tag_manifest.md',
        'sources\unresolved_unverified_manifest.md',
        'audit\v2-to-v3-migration.md',
        'audit\kb-quality-scorecard.md',
        'audit\kb-quality.json',
        'audit\kb-quality-history.json',
        'audit\badges\quality-badge.svg'
    )
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $Root $relative)) { $found.Add($relative) | Out-Null }
    }
    return @($found)
}

function Invoke-FrameworkScript {
    param([string]$ScriptName, [string]$Root)
    $scriptPath = Join-Path $ScriptDir $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        return [pscustomobject]@{ Name=$ScriptName; ExitCode=127; Output="Missing dependency: $scriptPath"; Success=$false }
    }
    try {
        $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
        $output = & $pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -KBRoot $Root 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
        return [pscustomobject]@{ Name=$ScriptName; ExitCode=$exitCode; Output=(($output | ForEach-Object { $_.ToString() }) -join "`n"); Success=($exitCode -eq 0) }
    } catch {
        return [pscustomobject]@{ Name=$ScriptName; ExitCode=99; Output=$_.Exception.Message; Success=$false }
    }
}

function Invoke-MigrationHelper {
    param([string]$ScriptName, [string[]]$Arguments)
    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return [pscustomobject]@{ Name=$ScriptName; ExitCode=127; Output="Missing dependency: $scriptPath"; Success=$false }
    }
    try {
        $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
        $output = '' | & $pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
        return [pscustomobject]@{ Name=$ScriptName; ExitCode=$exitCode; Output=(($output | ForEach-Object { $_.ToString() }) -join "`n"); Success=($exitCode -eq 0) }
    } catch {
        return [pscustomobject]@{ Name=$ScriptName; ExitCode=99; Output=$_.Exception.Message; Success=$false }
    }
}

function Test-ModelAssignmentBlock {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($content -match '(?m)^\s*model_assignment\s*:\s*$')
}

function Get-DetectedSourceVersion {
    param([string]$Root)
    $sources = Join-Path $Root 'sources'
    $assignmentFiles = @(
        (Join-Path $sources 'scoping_report.md'),
        (Join-Path $sources 'pipeline_state.md')
    )
    $hasAssignment = $false
    foreach ($path in $assignmentFiles) {
        if (Test-ModelAssignmentBlock -Path $path) { $hasAssignment = $true; break }
    }
    $registryPath = Join-Path $ScriptDir 'model-registry.yaml'
    if ($hasAssignment -and -not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { return 'v3.0' }
    if ($hasAssignment) { return 'v3.1' }
    return 'v2'
}

function Split-ModelValueAndComment {
    param([string]$Value)
    if ($Value -match '^(.*?)(\s+#.*)$') {
        return [pscustomobject]@{ Value=$matches[1].Trim(); Comment=$matches[2] }
    }
    return [pscustomobject]@{ Value=$Value.Trim(); Comment='' }
}

function Unquote-ModelValue {
    param([string]$Value)
    $text = $Value.Trim()
    if (($text.StartsWith('"') -and $text.EndsWith('"')) -or ($text.StartsWith("'") -and $text.EndsWith("'"))) {
        return $text.Substring(1, $text.Length - 2).Trim()
    }
    return $text
}

function Test-ModelAssignmentModelValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $text = (Unquote-ModelValue $Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    if ($text -match '[<>|]') { return $false }
    if ($text -match '(?i)^(null|not-required|required|true|false)$') { return $false }
    if ($text -match '(?i)^(sources/|audit/|full/|authority/|practice/)') { return $false }
    return ($text -match '[A-Za-z0-9]')
}

function Get-ModelValuesFromAssignmentValue {
    param([string]$RawValue)
    $split = Split-ModelValueAndComment -Value $RawValue
    $value = $split.Value
    $values = New-Object System.Collections.Generic.List[string]
    if ($value -match '^\[(.*)\]$') {
        $inner = $matches[1].Trim()
        if ($inner) {
            foreach ($part in ($inner -split ',')) {
                $model = Unquote-ModelValue $part
                if (Test-ModelAssignmentModelValue -Value $model) { $values.Add($model) | Out-Null }
            }
        }
    } else {
        $model = Unquote-ModelValue $value
        if (Test-ModelAssignmentModelValue -Value $model) { $values.Add($model) | Out-Null }
    }
    return @($values)
}

function Get-ModelAssignmentRows {
    param([string]$BlockText, [string]$Path)
    $skipKeys = @('preset','rule_19_opt_out','opt_out_rationale','validation_report','rule_19_exceptions')
    $rows = New-Object System.Collections.Generic.List[psobject]
    foreach ($line in ($BlockText -split "`r?`n")) {
        if ($line -match '^\s+([A-Za-z_][A-Za-z0-9_\-]*)\s*:\s*(.*?)\s*$') {
            $role = $matches[1]
            if ($skipKeys -contains $role) { continue }
            foreach ($modelId in (Get-ModelValuesFromAssignmentValue -RawValue $matches[2])) {
                $rows.Add([pscustomobject]@{ File=$Path; Role=$role; ModelId=$modelId; Handle=$null }) | Out-Null
            }
        }
    }
    return @($rows)
}

function Get-ModelAssignmentBlock {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*)model_assignment\s*:\s*$') {
            $baseIndent = $matches[1].Length
            $end = $i
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                $line = $lines[$j]
                $trimmed = $line.Trim()
                if ($trimmed -eq '```') { break }
                if ($trimmed -eq '') { break }
                $leading = ([regex]::Match($line, '^\s*')).Value.Length
                if ($leading -le $baseIndent -and $line -notmatch '^\s*#') { break }
                $end = $j
            }
            $blockText = ($lines[$i..$end] -join "`n")
            return [pscustomobject]@{
                Path=$Path
                Lines=$lines
                StartIndex=$i
                EndIndex=$end
                Text=$blockText
                Assignments=@(Get-ModelAssignmentRows -BlockText $blockText -Path $Path)
            }
        }
    }
    return $null
}

function Get-ModelProvider {
    param([string]$ModelId)
    $normalized = $ModelId.Trim().ToLowerInvariant()
    switch -Regex ($normalized) {
        '^openrouter[:/]' { return 'openrouter' }
        '^(claude|opus|sonnet|haiku)' { return 'copilot-cli' }
        '^(gpt|o1)' { return 'copilot-cli' }
        '^gemini' { return 'copilot-cli' }
        '^(mai|goldeneye)' { return 'copilot-cli' }
        '^(llama|qwen)' { return 'ollama' }
        default { return 'copilot-cli' }
    }
}

function Get-ModelIdForFamilyInference {
    param([string]$ModelId)
    $text = $ModelId.Trim()
    $text = $text -replace '(?i)^openrouter[:/]',''
    return $text
}

function Get-ModelShortName {
    param([string]$ModelId)
    $text = (Get-ModelIdForFamilyInference -ModelId $ModelId).ToLowerInvariant()
    $text = ($text -split '/')[-1]
    $text = $text -replace '[^a-z0-9]+','-'
    $text = ($text -replace '-+','-').Trim('-')
    if (-not $text) { return 'model' }
    return $text
}

function ConvertTo-HandlePart {
    param([string]$Text)
    $part = $Text.Trim().ToLowerInvariant() -replace '[^a-z0-9]+','-'
    $part = ($part -replace '-+','-').Trim('-')
    if (-not $part) { return 'model' }
    return $part
}

function New-SyntheticModelHandle {
    param([string]$Role, [string]$Provider, [string]$ModelId, [hashtable]$UsedHandles)
    $base = '{0}-{1}-{2}' -f (ConvertTo-HandlePart $Role), (ConvertTo-HandlePart $Provider), (Get-ModelShortName $ModelId)
    $handle = $base
    $suffix = 2
    while ($UsedHandles.ContainsKey($handle)) {
        $handle = '{0}-{1}' -f $base, $suffix
        $suffix++
    }
    $UsedHandles[$handle] = $true
    return $handle
}

function Get-InferredModelFamily {
    param([string]$ModelId)
    $inferId = Get-ModelIdForFamilyInference -ModelId $ModelId
    $result = Invoke-MigrationHelper -ScriptName 'Infer-Family.ps1' -Arguments @('-ModelId', $inferId)
    if (-not $result.Success) { return [pscustomobject]@{ Family='other'; Classified=$false; Output=$result.Output } }
    $allowed = @('anthropic','openai','google','meta-llama','mistral','deepseek','internal-microsoft','other')
    $lines = @($result.Output -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($allowed -contains $lines[$i]) {
            return [pscustomobject]@{ Family=$lines[$i]; Classified=($lines[$i] -ne 'other'); Output=$result.Output }
        }
    }
    return [pscustomobject]@{ Family='other'; Classified=$false; Output=$result.Output }
}

function Get-ProviderEndpointRef {
    param([string]$Provider)
    switch ($Provider) {
        'openrouter' { return 'env:OPENROUTER_ENDPOINT' }
        'ollama' { return 'env:OLLAMA_ENDPOINT' }
        default { return 'env:COPILOT_CLI_ENDPOINT' }
    }
}

function Get-ProviderApiKeyRef {
    param([string]$Provider)
    switch ($Provider) {
        'openrouter' { return 'env:OPENROUTER_API_KEY' }
        'ollama' { return 'env:OLLAMA_API_KEY' }
        default { return 'env:COPILOT_CLI_TOKEN' }
    }
}

function Get-ProviderCapabilities {
    param([string]$Provider)
    switch ($Provider) {
        'ollama' { return '[text, local, migrated-v3.0]' }
        'openrouter' { return '[text, migrated-v3.0]' }
        default { return '[text, tools, migrated-v3.0]' }
    }
}

function New-V3_1ModelRegistryData {
    param([object[]]$AssignmentRows)
    $byModelId = [ordered]@{}
    $usedHandles = @{}
    foreach ($row in $AssignmentRows) {
        if ($byModelId.Contains($row.ModelId)) { continue }
        $provider = Get-ModelProvider -ModelId $row.ModelId
        $handle = New-SyntheticModelHandle -Role $row.Role -Provider $provider -ModelId $row.ModelId -UsedHandles $usedHandles
        $familyResult = Get-InferredModelFamily -ModelId $row.ModelId
        $byModelId[$row.ModelId] = [pscustomobject]@{
            ModelId=$row.ModelId
            FirstRole=$row.Role
            Provider=$provider
            Handle=$handle
            Family=$familyResult.Family
            Classified=$familyResult.Classified
            InferenceOutput=$familyResult.Output
        }
    }
    foreach ($row in $AssignmentRows) { $row.Handle = $byModelId[$row.ModelId].Handle }
    return @($byModelId.Values)
}

function Write-V3_1ModelRegistry {
    param([object[]]$Models, [object[]]$AssignmentRows, [string]$Path)
    $recommended = [ordered]@{}
    foreach ($row in $AssignmentRows) {
        if (-not $recommended.Contains($row.Role)) { $recommended[$row.Role] = New-Object System.Collections.Generic.List[string] }
        if (-not $recommended[$row.Role].Contains($row.Handle)) { $recommended[$row.Role].Add($row.Handle) | Out-Null }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# KB Creation Framework v3.1 Model Registry') | Out-Null
    $lines.Add('# Synthesized by Migrate-V2KBtoV3.ps1 from legacy v3.0 model_assignment blocks.') | Out-Null
    $lines.Add("# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $lines.Add('version: 1') | Out-Null
    $lines.Add('recommended_assignment:') | Out-Null
    foreach ($role in $recommended.Keys) {
        $handles = @($recommended[$role])
        if ($handles.Count -eq 1) {
            $lines.Add("  ${role}: $($handles[0])") | Out-Null
        } else {
            $lines.Add("  ${role}: [$($handles -join ', ')]") | Out-Null
        }
    }
    $lines.Add('notes: "Synthesized from v3.0 raw model IDs; review provider endpoints, API key refs, and any family: other entries before production use."') | Out-Null
    $lines.Add('models:') | Out-Null
    foreach ($model in $Models) {
        $lines.Add("  - handle: $($model.Handle)") | Out-Null
        $lines.Add("    family: $($model.Family)") | Out-Null
        $lines.Add("    provider: $($model.Provider)") | Out-Null
        $lines.Add("    model_id: $($model.ModelId)") | Out-Null
        $lines.Add("    endpoint: $(Get-ProviderEndpointRef -Provider $model.Provider)") | Out-Null
        $lines.Add("    api_key: $(Get-ProviderApiKeyRef -Provider $model.Provider)") | Out-Null
        $lines.Add("    capabilities: $(Get-ProviderCapabilities -Provider $model.Provider)") | Out-Null
        $lines.Add(('    notes: "Synthesized from v3.0 model_assignment role ''{0}''."' -f $model.FirstRole)) | Out-Null
    }
    $lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Convert-ModelAssignmentValueToHandles {
    param([string]$RawValue, [hashtable]$ModelIdToHandle)
    $split = Split-ModelValueAndComment -Value $RawValue
    $value = $split.Value
    if ($value -match '^\[(.*)\]$') {
        $items = New-Object System.Collections.Generic.List[string]
        $inner = $matches[1].Trim()
        if ($inner) {
            foreach ($part in ($inner -split ',')) {
                $model = Unquote-ModelValue $part
                if ($ModelIdToHandle.ContainsKey($model)) { $items.Add($ModelIdToHandle[$model]) | Out-Null } else { $items.Add($part.Trim()) | Out-Null }
            }
        }
        return ('[' + (($items.ToArray()) -join ', ') + ']' + $split.Comment)
    }
    $modelValue = Unquote-ModelValue $value
    if ($ModelIdToHandle.ContainsKey($modelValue)) { return ($ModelIdToHandle[$modelValue] + $split.Comment) }
    return ($value + $split.Comment)
}

function Convert-ModelAssignmentBlockToHandles {
    param([string]$BlockText, [hashtable]$ModelIdToHandle)
    $skipKeys = @('preset','rule_19_opt_out','opt_out_rationale','validation_report','rule_19_exceptions')
    $updated = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($BlockText -split "`r?`n")) {
        if ($line -match '^(\s+([A-Za-z_][A-Za-z0-9_\-]*)\s*:\s*)(.*?)\s*$') {
            $prefix = $matches[1]
            $role = $matches[2]
            $rawValue = $matches[3]
            if ($skipKeys -notcontains $role) {
                $updated.Add($prefix + (Convert-ModelAssignmentValueToHandles -RawValue $rawValue -ModelIdToHandle $ModelIdToHandle)) | Out-Null
                continue
            }
        }
        $updated.Add($line) | Out-Null
    }
    return ($updated.ToArray() -join "`n")
}

function Update-ModelAssignmentBlockInFile {
    param([object]$Block, [hashtable]$ModelIdToHandle)
    $newBlock = Convert-ModelAssignmentBlockToHandles -BlockText $Block.Text -ModelIdToHandle $ModelIdToHandle
    $output = New-Object System.Collections.Generic.List[string]
    if ($Block.StartIndex -gt 0) {
        foreach ($line in $Block.Lines[0..($Block.StartIndex - 1)]) { $output.Add($line) | Out-Null }
    }
    foreach ($line in ($newBlock -split "`r?`n")) { $output.Add($line) | Out-Null }
    if ($Block.EndIndex -lt ($Block.Lines.Count - 1)) {
        foreach ($line in $Block.Lines[($Block.EndIndex + 1)..($Block.Lines.Count - 1)]) { $output.Add($line) | Out-Null }
    }
    $output.ToArray() -join "`n" | Set-Content -LiteralPath $Block.Path -Encoding UTF8
}

function Write-V3_0ToV3_1MigrationReport {
    param(
        [string]$Path,
        [string]$Root,
        [string]$RegistryPath,
        [object[]]$AssignmentRows,
        [object[]]$Models,
        [object[]]$ResolveResults,
        [string[]]$Warnings
    )
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# v3.0 to v3.1 Migration Report') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Migration date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $lines.Add("- Script version: $ScriptVersion") | Out-Null
    $lines.Add("- KB root: ``$Root``") | Out-Null
    $lines.Add("- Registry path written: ``$RegistryPath``") | Out-Null
    $lines.Add("- Force used: $Force") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Original assignment to synthesized handles') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| File | Role | Original model_id | Synthesized handle |') | Out-Null
    $lines.Add('|---|---|---|---|') | Out-Null
    foreach ($row in $AssignmentRows) {
        $relativeFile = $row.File
        if ($relativeFile.StartsWith($Root)) { $relativeFile = $relativeFile.Substring($Root.Length).TrimStart([char]'\') }
        $lines.Add("| $(Escape-Md $relativeFile) | $(Escape-Md $row.Role) | $(Escape-Md $row.ModelId) | $(Escape-Md $row.Handle) |") | Out-Null
    }
    if ($AssignmentRows.Count -eq 0) { $lines.Add('| — | — | — | — |') | Out-Null }
    $lines.Add('') | Out-Null
    $lines.Add('## Synthesized registry entries') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Handle | Provider | Family | Model ID | First role |') | Out-Null
    $lines.Add('|---|---|---|---|---|') | Out-Null
    foreach ($model in $Models) {
        $lines.Add("| $(Escape-Md $model.Handle) | $(Escape-Md $model.Provider) | $(Escape-Md $model.Family) | $(Escape-Md $model.ModelId) | $(Escape-Md $model.FirstRole) |") | Out-Null
    }
    $unclassified = @($Models | Where-Object { -not $_.Classified })
    $lines.Add('') | Out-Null
    $lines.Add('## Models requiring family review') | Out-Null
    $lines.Add('') | Out-Null
    if ($unclassified.Count -eq 0) {
        $lines.Add('- None. All models were classified by Infer-Family.ps1.') | Out-Null
    } else {
        foreach ($model in $unclassified) {
            $lines.Add("- ``$($model.ModelId)`` -> ``$($model.Handle)`` currently has ``family: $($model.Family)``; operator must hand-edit family if this is not correct.") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Resolve-Model.ps1 validation') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Handle | Exit code | Status | Output excerpt |') | Out-Null
    $lines.Add('|---|---:|---|---|') | Out-Null
    foreach ($result in $ResolveResults) {
        $excerpt = $result.Output
        if ($excerpt.Length -gt 300) { $excerpt = $excerpt.Substring(0, 300) + ' …' }
        $status = if ($result.Success) { 'OK' } else { 'CAVEAT' }
        $lines.Add("| $(Escape-Md $result.Handle) | $($result.ExitCode) | $status | $(Escape-Md $excerpt) |") | Out-Null
    }
    if ($ResolveResults.Count -eq 0) { $lines.Add('| — | — | — | — |') | Out-Null }
    if ($Warnings.Count -gt 0) {
        $lines.Add('') | Out-Null
        $lines.Add('## Migration warnings') | Out-Null
        $lines.Add('') | Out-Null
        foreach ($warning in $Warnings) { $lines.Add("- $warning") | Out-Null }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Files updated') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('- `model-registry.yaml` at the operator framework root.') | Out-Null
    $lines.Add('- `sources/scoping_report.md` model_assignment block, when present.') | Out-Null
    $lines.Add('- `sources/pipeline_state.md` model_assignment block, when present.') | Out-Null
    $lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Convert-V3_0ToV3_1 {
    param([string]$Root)
    $sources = Join-Path $Root 'sources'
    $audit = Join-Path $Root 'audit'
    $registryPath = Join-Path $ScriptDir 'model-registry.yaml'
    $reportPath = Join-Path $audit 'v3.0-to-v3.1-migration.md'
    $assignmentFiles = @(
        (Join-Path $sources 'scoping_report.md'),
        (Join-Path $sources 'pipeline_state.md')
    )

    $blocks = New-Object System.Collections.Generic.List[psobject]
    foreach ($path in $assignmentFiles) {
        $block = Get-ModelAssignmentBlock -Path $path
        if ($null -ne $block) { $blocks.Add($block) | Out-Null }
    }
    if ($blocks.Count -eq 0) {
        [Console]::Error.WriteLine('Cannot migrate: v3.0 source selected but no model_assignment block was found in sources/scoping_report.md or sources/pipeline_state.md.')
        Exit-Script 2
    }

    $assignmentRows = @($blocks | ForEach-Object { $_.Assignments } | Where-Object { $null -ne $_ })
    if ($assignmentRows.Count -eq 0) {
        [Console]::Error.WriteLine('Cannot migrate: model_assignment block was found, but no assigned model IDs were detected.')
        Exit-Script 2
    }

    if ($DryRun) {
        $uniqueCount = @($assignmentRows | Select-Object -ExpandProperty ModelId -Unique).Count
        Write-Host "Dry run: recognizable v3.0 KB at $Root"
        Write-Host "Would synthesize model-registry.yaml at $registryPath with $uniqueCount unique model entry/entries."
        Write-Host "Would rewrite model_assignment block(s) in $($blocks.Count) source file(s) and write audit/v3.0-to-v3.1-migration.md."
        Exit-Script 0
    }

    $blockingArtifacts = New-Object System.Collections.Generic.List[string]
    if ((Test-Path -LiteralPath $registryPath -PathType Leaf) -and -not $Force) { $blockingArtifacts.Add($registryPath) | Out-Null }
    if ((Test-Path -LiteralPath $reportPath -PathType Leaf) -and -not $Force) { $blockingArtifacts.Add($reportPath) | Out-Null }
    if ($blockingArtifacts.Count -gt 0) {
        [Console]::Error.WriteLine("Cannot migrate: v3.1 migration artifacts already exist. Re-run with -Force to overwrite. Existing: $($blockingArtifacts -join ', ')")
        Exit-Script 2
    }

    if (-not (Test-Path -LiteralPath $audit -PathType Container)) { New-Item -ItemType Directory -Path $audit -Force | Out-Null }

    $models = @(New-V3_1ModelRegistryData -AssignmentRows $assignmentRows)
    $modelIdToHandle = @{}
    foreach ($model in $models) { $modelIdToHandle[$model.ModelId] = $model.Handle }

    Write-V3_1ModelRegistry -Models $models -AssignmentRows $assignmentRows -Path $registryPath

    foreach ($block in $blocks) { Update-ModelAssignmentBlockInFile -Block $block -ModelIdToHandle $modelIdToHandle }

    $warnings = New-Object System.Collections.Generic.List[string]
    $unclassified = @($models | Where-Object { -not $_.Classified })
    foreach ($model in $unclassified) { $warnings.Add("Model '$($model.ModelId)' was classified as family '$($model.Family)'; operator should hand-edit model-registry.yaml if needed.") | Out-Null }

    $resolveResults = New-Object System.Collections.Generic.List[psobject]
    foreach ($model in $models) {
        $result = Invoke-MigrationHelper -ScriptName 'Resolve-Model.ps1' -Arguments @('-Handle', $model.Handle, '-RegistryPath', $registryPath)
        $resolveResults.Add([pscustomobject]@{ Handle=$model.Handle; ExitCode=$result.ExitCode; Output=$result.Output; Success=$result.Success }) | Out-Null
        if (-not $result.Success) { $warnings.Add("Resolve-Model.ps1 could not resolve synthesized handle '$($model.Handle)'.") | Out-Null }
    }

    Write-V3_0ToV3_1MigrationReport -Path $reportPath -Root $Root -RegistryPath $registryPath -AssignmentRows $assignmentRows -Models $models -ResolveResults @($resolveResults) -Warnings @($warnings)

    Write-Host "Model registry: $registryPath"
    Write-Host "Updated model_assignment block(s): $($blocks.Count) file(s)."
    Write-Host "Migration report: $reportPath"
    if ($warnings.Count -gt 0) { Exit-Script 1 }
    Exit-Script 0
}

function Get-VolatileRows {
    param([System.IO.FileInfo[]]$FullFiles)
    $rows = New-Object System.Collections.Generic.List[psobject]
    $id = 1
    foreach ($file in $FullFiles) {
        $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($m in [regex]::Matches($lines[$i], '\[VOLATILE:([^\]]+)\]')) {
                $claim = Get-ClaimText -Lines $lines -Index $i
                $anchor = Get-NearestHeadingAnchor -Lines $lines -Index $i
                $location = "line $($i + 1)"
                if ($anchor) { $location = "$location; $anchor" }
                $rows.Add([pscustomobject]@{
                    volatile_id = ('VOL-{0:0000}' -f $id)
                    file = "full/$($file.Name)"
                    location = $location
                    volatile_type = "[VOLATILE:$($m.Groups[1].Value.Trim())]"
                    claim_text = $claim
                    current_value = Get-BestEffortCurrentValue $claim
                    as_of_date = Get-NearbyAsOfDate -Lines $lines -Index $i
                    next_review_due = 'null'
                }) | Out-Null
                $id++
            }
        }
    }
    return @($rows)
}

function Get-UnverifiedRows {
    param([System.IO.FileInfo[]]$FullFiles)
    $rows = New-Object System.Collections.Generic.List[psobject]
    $id = 1
    foreach ($file in $FullFiles) {
        $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($m in [regex]::Matches($lines[$i], '\[(UNVERIFIED|NEEDS-VERIFICATION)\]')) {
                $location = "full/$($file.Name):$($i + 1)"
                $rows.Add([pscustomobject]@{
                    unverified_id = ('UV-{0:0000}' -f $id)
                    originating_builder = 'unknown-v2'
                    original_location = $location
                    assembled_file = $location
                    assembled_location = $location
                    claim_text = Get-ClaimText -Lines $lines -Index $i
                    original_tag = "[$($m.Groups[1].Value)]"
                    assembly_disposition = 'retained-tagged-v2'
                    lead_approval = 'synthesized-by-migration-script'
                    phase6b_priority = 'P1'
                }) | Out-Null
                $id++
            }
        }
    }
    return @($rows)
}

function Write-VolatileManifest {
    param([object[]]$Rows, [string]$Path, [string]$Root)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Volatile Tag Manifest — synthesized by v2-to-v3 migration') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- KB root: ``$Root``") | Out-Null
    $lines.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $lines.Add('- Provenance: retroactive scan of v2 `full/*.md`; no model calls.') | Out-Null
    $lines.Add("- Rows: **$($Rows.Count)**") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| volatile_id | file | location | volatile_type | claim_text | current_value | as_of_date | next_review_due |') | Out-Null
    $lines.Add('|---|---|---|---|---|---|---|---|') | Out-Null
    foreach ($row in $Rows) {
        $lines.Add("| $($row.volatile_id) | $($row.file) | $(Escape-Md $row.location) | $(Escape-Md $row.volatile_type) | $(Escape-Md $row.claim_text) | $(Escape-Md $row.current_value) | $(Escape-Md $row.as_of_date) | $($row.next_review_due) |") | Out-Null
    }
    if ($Rows.Count -eq 0) { $lines.Add('| — | — | — | — | — | — | — | — |') | Out-Null }
    $lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-UnverifiedManifest {
    param([object[]]$Rows, [string]$Path, [string]$Root)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Unresolved Unverified Manifest — synthesized by v2-to-v3 migration') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- KB root: ``$Root``") | Out-Null
    $lines.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $lines.Add('- Provenance: retroactive scan of v2 `full/*.md`; no model calls.') | Out-Null
    $lines.Add("- Rows: **$($Rows.Count)**") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| unverified_id | originating_builder | original_location | assembled_file | assembled_location | claim_text | original_tag | assembly_disposition | lead_approval | phase6b_priority |') | Out-Null
    $lines.Add('|---|---|---|---|---|---|---|---|---|---|') | Out-Null
    foreach ($row in $Rows) {
        $lines.Add("| $($row.unverified_id) | $($row.originating_builder) | $(Escape-Md $row.original_location) | $(Escape-Md $row.assembled_file) | $(Escape-Md $row.assembled_location) | $(Escape-Md $row.claim_text) | $(Escape-Md $row.original_tag) | $($row.assembly_disposition) | $($row.lead_approval) | $($row.phase6b_priority) |") | Out-Null
    }
    if ($Rows.Count -eq 0) { $lines.Add('| — | — | — | — | — | — | — | — | — | — |') | Out-Null }
    $lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-ScorecardSummary {
    param([string]$JsonPath)
    if (-not (Test-Path -LiteralPath $JsonPath)) {
        return [pscustomobject]@{ Present=$false; Verdict='not-generated'; QualityIndex=$null; MissingArtifacts=@(); MissingStructure=@(); IncompleteDimensions=@() }
    }
    try {
        $score = Get-Content -LiteralPath $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $missingArtifacts = if ($null -ne $score.missing_artifacts) { @($score.missing_artifacts) } else { @() }
        $missingStructure = if ($null -ne $score.missing_structure) { @($score.missing_structure) } else { @() }
        $incomplete = New-Object System.Collections.Generic.List[string]
        $missingText = (($missingArtifacts + $missingStructure) -join "`n")
        $dimensionArtifactMap = [ordered]@{
            'Citation density & primary-source rate' = 'table-of-authorities|factcheck_'
            'Register-tag coverage & extraction integrity' = 'register_lint_report|authority_view_extraction|practice'
            'Cross-reference fidelity' = 'factcheck_operative_claims|filename_validation'
            'Qualifier preservation' = 'factcheck_operative_claims|audit_report|qualifier-registry'
            'Volatile-tag coverage' = 'volatile_tag_manifest'
            'Stress-test pass rate' = 'stress_test_report_'
            'Structural & size compliance' = 'full|authority|practice|sources|AGENTS|index|table-of-authorities|filename_validation|quality_tier_audit'
        }
        foreach ($key in $dimensionArtifactMap.Keys) {
            if ($missingText -match $dimensionArtifactMap[$key]) { $incomplete.Add($key) | Out-Null }
        }
        return [pscustomobject]@{
            Present=$true
            Verdict=$score.verdict
            QualityIndex=$score.kb_quality_index
            MissingArtifacts=$missingArtifacts
            MissingStructure=$missingStructure
            IncompleteDimensions=@($incomplete)
        }
    } catch {
        return [pscustomobject]@{ Present=$true; Verdict='unreadable-json'; QualityIndex=$null; MissingArtifacts=@(); MissingStructure=@(); IncompleteDimensions=@('Scorecard JSON unreadable') }
    }
}

function Write-MigrationReport {
    param(
        [string]$Path,
        [string]$Root,
        [hashtable]$Baseline,
        [object]$PracticeRetention,
        [object]$AuthorityRetention,
        [object[]]$VolatileRows,
        [object[]]$UnverifiedRows,
        [object[]]$StepResults,
        [object]$ScorecardSummary,
        [string[]]$Warnings
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# v2 to v3 Migration Report') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Migration date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
    $lines.Add("- Script version: $ScriptVersion") | Out-Null
    $lines.Add("- KB root: ``$Root``") | Out-Null
    $lines.Add("- Force used: $Force") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## v2 baseline state') | Out-Null
    $lines.Add('') | Out-Null
    foreach ($key in $Baseline.Keys) { $lines.Add("- ${key}: $($Baseline[$key])") | Out-Null }
    $lines.Add('') | Out-Null
    $lines.Add('## Migration steps') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Step | Exit code | Status | Output excerpt |') | Out-Null
    $lines.Add('|---|---:|---|---|') | Out-Null
    foreach ($result in $StepResults) {
        $status = if ($result.Success) { 'OK' } else { 'CAVEAT' }
        $excerpt = $result.Output
        if ($excerpt.Length -gt 500) { $excerpt = $excerpt.Substring(0, 500) + ' …' }
        $lines.Add("| $(Escape-Md $result.Name) | $($result.ExitCode) | $status | $(Escape-Md $excerpt) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Synthesized retroactively') | Out-Null
    $lines.Add('') | Out-Null
    $practiceRatio = if ($PracticeRetention.Ratio -ne $null) { "$($PracticeRetention.Ratio)%" } else { 'not generated' }
    $authorityRatio = if ($AuthorityRetention.Ratio -ne $null) { "$($AuthorityRetention.Ratio)%" } else { 'not generated' }
    $lines.Add("- Volatile tags found: **$($VolatileRows.Count)**") | Out-Null
    $lines.Add("- Unresolved verification tags found: **$($UnverifiedRows.Count)**") | Out-Null
    $lines.Add("- practice/ retention: **$practiceRatio** ($($PracticeRetention.Files) peer file(s))") | Out-Null
    $lines.Add("- authority/ retention: **$authorityRatio** ($($AuthorityRetention.Files) peer file(s))") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Genuinely missing / scorecard caveats') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Scorecard verdict: **$($ScorecardSummary.Verdict)**") | Out-Null
    if ($ScorecardSummary.QualityIndex -ne $null) { $lines.Add("- KB Quality Index: **$($ScorecardSummary.QualityIndex) / 100**") | Out-Null }
    if ($ScorecardSummary.IncompleteDimensions.Count -gt 0) {
        $lines.Add('- Dimensions affected by missing v3 evidence:') | Out-Null
        foreach ($d in $ScorecardSummary.IncompleteDimensions) { $lines.Add("  - $d") | Out-Null }
    } else {
        $lines.Add('- Dimensions affected by missing v3 evidence: none detected mechanically.') | Out-Null
    }
    if ($ScorecardSummary.MissingArtifacts.Count -gt 0) {
        $lines.Add('- Missing scorecard artifacts:') | Out-Null
        foreach ($m in $ScorecardSummary.MissingArtifacts) { $lines.Add("  - ``$m``") | Out-Null }
    }
    if ($ScorecardSummary.MissingStructure.Count -gt 0) {
        $lines.Add('- Missing expected structure:') | Out-Null
        foreach ($m in $ScorecardSummary.MissingStructure) { $lines.Add("  - ``$m``") | Out-Null }
    }
    if ($Warnings.Count -gt 0) {
        $lines.Add('') | Out-Null
        $lines.Add('## Migration warnings') | Out-Null
        $lines.Add('') | Out-Null
        foreach ($warning in $Warnings) { $lines.Add("- $warning") | Out-Null }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Recommended next actions') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('- Run a v3 refresh cycle to populate missing stress-test, phase-audit, and model-assignment artifacts before treating the KB as fully v3-built.') | Out-Null
    $lines.Add('- Resolve rows in `sources/unresolved_unverified_manifest.md` as Phase 6b P1 items.') | Out-Null
    $lines.Add('- Review `sources/volatile_tag_manifest.md` and fill any `operator-review-required` current values before the next refresh cycle.') | Out-Null
    $lines.Add('- Rebuild under v3 if the scorecard remains BUILD-INCOMPLETE or if downstream reliance requires full v3 quality assurance.') | Out-Null
    $lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
}

if ($Help) {
    Show-Help
    Exit-Script 0
}

if ($FromVersion -and (@('v2','v3.0') -notcontains $FromVersion)) {
    [Console]::Error.WriteLine("Invalid -FromVersion '$FromVersion'. Allowed values: v2, v3.0.")
    Exit-Script 2
}

if ([string]::IsNullOrWhiteSpace($KBRoot)) {
    [Console]::Error.WriteLine('Cannot migrate: -KBRoot is required unless -Help is used.')
    Show-Help
    Exit-Script 2
}

if (-not (Test-Path -LiteralPath $KBRoot)) {
    Write-CannotMigrate "KBRoot not found: $KBRoot"
    Exit-Script 2
}
$KBRoot = (Resolve-Path -LiteralPath $KBRoot).Path

$effectiveFromVersion = if ($FromVersion) { $FromVersion } else { Get-DetectedSourceVersion -Root $KBRoot }
Write-Host "Migration source version: $effectiveFromVersion"
if ($effectiveFromVersion -eq 'v3.1') {
    [Console]::Error.WriteLine('Cannot migrate: model_assignment exists and model-registry.yaml is already present at the framework root. This appears to be v3.1 already; use -FromVersion v2 only if you intentionally want the legacy v2 quality-artifact migration path.')
    Exit-Script 2
}
if ($effectiveFromVersion -eq 'v3.0') { Convert-V3_0ToV3_1 -Root $KBRoot }

$agentsPath = Join-Path $KBRoot 'AGENTS.md'
$fullDir = Join-Path $KBRoot 'full'
$sourcesDir = Join-Path $KBRoot 'sources'
$authorityDir = Join-Path $KBRoot 'authority'
$practiceDir = Join-Path $KBRoot 'practice'
$archiveDir = Join-Path $KBRoot 'authority.v2-archive'
$auditDir = Join-Path $KBRoot 'audit'
$reportPath = Join-Path $auditDir 'v2-to-v3-migration.md'
$volatilePath = Join-Path $sourcesDir 'volatile_tag_manifest.md'
$unverifiedPath = Join-Path $sourcesDir 'unresolved_unverified_manifest.md'
$scorecardJsonPath = Join-Path $auditDir 'kb-quality.json'

$missing = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) { $missing.Add('AGENTS.md') | Out-Null }
if (-not (Test-Path -LiteralPath $fullDir -PathType Container)) { $missing.Add('full/') | Out-Null }
if (-not (Test-Path -LiteralPath $sourcesDir -PathType Container)) { $missing.Add('sources/') | Out-Null }
$fullFiles = if (Test-Path -LiteralPath $fullDir -PathType Container) { @(Get-ChildItem -LiteralPath $fullDir -Filter '*.md' -File) } else { @() }
if ($fullFiles.Count -eq 0) { $missing.Add('full/*.md topic file') | Out-Null }
if ($missing.Count -gt 0) {
    Write-CannotMigrate ("Missing required v2 structure: " + (($missing | Select-Object -Unique) -join ', '))
    Exit-Script 2
}

$existingArtifacts = @(Get-ExistingV3Artifacts -Root $KBRoot)
if ($existingArtifacts.Count -gt 0 -and -not $Force) {
    [Console]::Error.WriteLine("Cannot migrate: v3 artifacts already exist. Re-run with -Force to overwrite. Existing: $($existingArtifacts -join ', ')")
    Exit-Script 2
}

$baseline = [ordered]@{
    'AGENTS.md present' = (Test-Path -LiteralPath $agentsPath -PathType Leaf)
    'full/ topic files' = $fullFiles.Count
    'sources/ present' = (Test-Path -LiteralPath $sourcesDir -PathType Container)
    'authority/ present' = (Test-Path -LiteralPath $authorityDir -PathType Container)
    'authority/ markdown files' = if (Test-Path -LiteralPath $authorityDir -PathType Container) { @(Get-ChildItem -LiteralPath $authorityDir -Filter '*.md' -File).Count } else { 0 }
    'practice/ already present' = (Test-Path -LiteralPath $practiceDir -PathType Container)
    'pre-existing v3 artifacts' = if ($existingArtifacts.Count -gt 0) { $existingArtifacts -join ', ' } else { 'none' }
}

$volatileRows = @(Get-VolatileRows -FullFiles $fullFiles)
$unverifiedRows = @(Get-UnverifiedRows -FullFiles $fullFiles)

if ($DryRun) {
    Write-Host "Dry run: recognizable v2 KB at $KBRoot"
    Write-Host "Would archive authority/ to authority.v2-archive/ if present, regenerate practice/ and authority/, synthesize manifests, run scorecard, and write audit/v2-to-v3-migration.md."
    Write-Host "Would synthesize $($volatileRows.Count) volatile row(s) and $($unverifiedRows.Count) unresolved verification row(s)."
    Exit-Script 0
}

if (-not (Test-Path -LiteralPath $auditDir)) { New-Item -ItemType Directory -Path $auditDir -Force | Out-Null }

if ($Force) {
    foreach ($path in @($practiceDir, $archiveDir)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
    foreach ($path in @($volatilePath, $unverifiedPath, $reportPath, (Join-Path $auditDir 'kb-quality-scorecard.md'), (Join-Path $auditDir 'kb-quality.json'), (Join-Path $auditDir 'kb-quality-history.json'))) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

$warnings = New-Object System.Collections.Generic.List[string]
$stepResults = New-Object System.Collections.Generic.List[psobject]

$practiceResult = Invoke-FrameworkScript -ScriptName 'Extract-PracticeView.ps1' -Root $KBRoot
$stepResults.Add($practiceResult) | Out-Null
if (-not $practiceResult.Success) { $warnings.Add("Extract-PracticeView.ps1 returned $($practiceResult.ExitCode); migration continued.") | Out-Null }

if (Test-Path -LiteralPath $authorityDir -PathType Container) {
    if (Test-Path -LiteralPath $archiveDir) { Remove-Item -LiteralPath $archiveDir -Recurse -Force }
    Copy-Item -LiteralPath $authorityDir -Destination $archiveDir -Recurse
    Remove-Item -LiteralPath $authorityDir -Recurse -Force
    Write-Host "Archived v2 authority/ to authority.v2-archive/."
} else {
    $warnings.Add('No authority/ directory was present to archive before v3 re-extraction.') | Out-Null
}

$authorityResult = Invoke-FrameworkScript -ScriptName 'Extract-AuthorityView.ps1' -Root $KBRoot
$stepResults.Add($authorityResult) | Out-Null
if (-not $authorityResult.Success) { $warnings.Add("Extract-AuthorityView.ps1 returned $($authorityResult.ExitCode); migration continued.") | Out-Null }

Write-VolatileManifest -Rows $volatileRows -Path $volatilePath -Root $KBRoot
Write-UnverifiedManifest -Rows $unverifiedRows -Path $unverifiedPath -Root $KBRoot

$scorecardResult = Invoke-FrameworkScript -ScriptName 'Generate-QualityScorecard.ps1' -Root $KBRoot
$stepResults.Add($scorecardResult) | Out-Null
if (-not $scorecardResult.Success) { $warnings.Add("Generate-QualityScorecard.ps1 returned $($scorecardResult.ExitCode); verdict logged, migration continued.") | Out-Null }

$practiceRetention = Get-ViewRetention -FullFiles $fullFiles -ViewDir $practiceDir
$authorityRetention = Get-ViewRetention -FullFiles $fullFiles -ViewDir $authorityDir
$scorecardSummary = Get-ScorecardSummary -JsonPath $scorecardJsonPath

if (-not $scorecardSummary.Present) { $warnings.Add('Quality scorecard JSON was not generated.') | Out-Null }

Write-MigrationReport -Path $reportPath -Root $KBRoot -Baseline $baseline -PracticeRetention $practiceRetention -AuthorityRetention $authorityRetention -VolatileRows $volatileRows -UnverifiedRows $unverifiedRows -StepResults @($stepResults) -ScorecardSummary $scorecardSummary -Warnings @($warnings)

Write-Host "Migration report: $reportPath"
Write-Host "Synthesized manifests: $($volatileRows.Count) volatile row(s), $($unverifiedRows.Count) unresolved verification row(s)."
Write-Host "Scorecard verdict: $($scorecardSummary.Verdict)"

$extractionFailures = @($practiceResult, $authorityResult) | Where-Object { -not $_.Success }
$hasBuildIncomplete = ($scorecardSummary.Verdict -eq 'BUILD-INCOMPLETE' -or $scorecardSummary.IncompleteDimensions.Count -gt 0 -or -not $scorecardSummary.Present)
if ($extractionFailures.Count -gt 0 -or $hasBuildIncomplete) { Exit-Script 1 }
Exit-Script 0
