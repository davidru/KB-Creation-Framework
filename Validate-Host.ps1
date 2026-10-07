# Title: Validate-Host.ps1 — KB Framework host runtime smoke test.
# Purpose: Verify HOST-CONTRACT v3.1 capabilities and observed capability level.
# Version: 3.1.1 patch for v3.1 L2a host-validation gap.
# Inputs: Optional -Host, -RegistryPath, -Handle, -OutPath, -UpdateHostNotes, -SkipLiveDispatch, -Help.
# Exit codes: 0 valid observed level; 1 minimum host contract failure; 2 indeterminate because live prerequisites were skipped.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [Alias('Host')]
    [ValidateSet('copilot-cli','opencode')]
    [string]$HostName = '',

    [Parameter(Mandatory=$false)]
    [string]$RegistryPath = (Join-Path $PSScriptRoot 'model-registry.example.yaml'),

    [Parameter(Mandatory=$false)]
    [string]$Handle = '',

    [Parameter(Mandatory=$false)]
    [string]$OutPath = '',

    [Parameter(Mandatory=$false)]
    [switch]$UpdateHostNotes,

    [Parameter(Mandatory=$false)]
    [switch]$SkipLiveDispatch,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

$Script:ValidateHostVersion = '3.1.1'
$Script:FrameworkRoot = $PSScriptRoot
$Script:ResolverPath = Join-Path $Script:FrameworkRoot 'Resolve-Model.ps1'
$Script:AdaptersRoot = Join-Path $Script:FrameworkRoot 'adapters\model-providers'
$Script:ScratchRoot = Join-Path $Script:FrameworkRoot '.kbframework-host-validation'
$Script:Checks = New-Object System.Collections.Generic.List[object]
$Script:LiveDispatchTested = $false
$Script:LiveDispatchExplanation = ''
$Script:SelectedHandle = ''
$Script:SelectedResolvedHandle = $null
$Script:SingleDispatchSeconds = $null
$Script:Check5MaxConcurrencyObserved = 0
$Script:Check6FamiliesTested = @()

function Show-Usage {
    $usage = @'
Validate-Host.ps1 v3.1.1

Usage:
  pwsh -NoProfile -File .\Validate-Host.ps1 [-Host copilot-cli|opencode] [-RegistryPath <path>] [-Handle <handle>] [-OutPath <path>] [-UpdateHostNotes] [-SkipLiveDispatch]

Parameters:
  -Host               Host to validate. Defaults to ~/.kbframework/host_preference.yaml, environment, then copilot-cli.
  -RegistryPath       Model registry YAML path. Defaults to model-registry.example.yaml beside this script.
  -Handle             Registry handle for live dispatch. Defaults to first usable handle with required env vars present.
  -OutPath            Markdown report path. If omitted, the Markdown report is written to stdout.
  -UpdateHostNotes    After a determinate runtime validation, update hosts/<host>/HOST-NOTES.md.
  -SkipLiveDispatch   Skip model-backed checks 4-6.
  -Help               Print this usage and exit 0.
'@
    Write-Output $usage
}

function Add-CheckResult {
    param(
        [Parameter(Mandatory=$true)][int]$Number,
        [Parameter(Mandatory=$true)][string]$Check,
        [Parameter(Mandatory=$true)][ValidateSet('PASS','WARN','FAIL','SKIPPED')][string]$Status,
        [Parameter(Mandatory=$true)][string]$Evidence,
        [Parameter(Mandatory=$false)]$Data = $null
    )

    $Script:Checks.Add([pscustomobject][ordered]@{
        number = $Number
        check = $Check
        status = $Status
        evidence = $Evidence
        data = $Data
    }) | Out-Null
}

function Get-CheckStatus {
    param([Parameter(Mandatory=$true)][int]$Number)
    $item = @($Script:Checks | Where-Object { $_.number -eq $Number } | Select-Object -First 1)
    if ($item.Count -eq 0) { return 'SKIPPED' }
    return [string]$item[0].status
}

function Escape-MarkdownCell {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return ([string]$Value -replace '\|','\|' -replace "`r?`n", ' ')
}

function Resolve-RegistryPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).Path }
    throw "RegistryPath not found: $Path"
}

function ConvertFrom-RegistryYamlValue {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '' }
    $text = $Value.Trim()
    if ($text -match '^\[(.*)\]$') {
        $inner = $matches[1].Trim()
        if (-not $inner) { return @() }
        return @($inner -split ',' | ForEach-Object { ConvertFrom-RegistryYamlValue -Value $_ })
    }
    if (($text.StartsWith('"') -and $text.EndsWith('"')) -or ($text.StartsWith("'") -and $text.EndsWith("'"))) {
        return $text.Substring(1, $text.Length - 2)
    }
    return $text
}

function Add-RegistryProperty {
    param([System.Collections.Specialized.OrderedDictionary]$Entry, [string]$Text)
    if ($Text -match '^([A-Za-z_][A-Za-z0-9_\-]*)\s*:\s*(.*)$') {
        $key = $matches[1]
        $parsed = @(ConvertFrom-RegistryYamlValue -Value $matches[2])
        if ($parsed.Count -eq 0) { $Entry[$key] = @(); return }
        if ($parsed.Count -eq 1) { $Entry[$key] = $parsed[0]; return }
        $Entry[$key] = $parsed
    }
}

function ConvertFrom-ModelRegistryYaml {
    param([Parameter(Mandatory=$true)][string]$Path)
    $ErrorActionPreference = 'Stop'
    $models = @()
    $current = $null
    $inModels = $false
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $raw.TrimEnd()
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -eq 'models:') { $inModels = $true; continue }
        if (-not $inModels) { continue }
        if ($line -match '^\s*-\s*(.*)$') {
            if ($null -ne $current) { $models += [pscustomobject]$current }
            $current = [ordered]@{}
            $rest = $matches[1].Trim()
            if ($rest) { Add-RegistryProperty -Entry $current -Text $rest }
        } elseif ($null -ne $current -and $line -match '^\s+([A-Za-z_][A-Za-z0-9_\-]*\s*:.*)$') {
            Add-RegistryProperty -Entry $current -Text $matches[1]
        }
    }
    if ($null -ne $current) { $models += [pscustomobject]$current }
    return @($models)
}

function Get-Prop {
    param($Entry, [Parameter(Mandatory=$true)][string]$Name)
    if ($null -eq $Entry) { return $null }
    $property = $Entry.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Get-EnvName {
    param([AllowNull()][string]$Value)
    if ($Value -match '^env:([A-Za-z_][A-Za-z0-9_]*)$') { return $matches[1] }
    return $null
}

function Get-RequiredEnvNamesForEntry {
    param($Entry)
    $provider = [string](Get-Prop -Entry $Entry -Name 'provider')
    $required = New-Object System.Collections.Generic.List[string]

    foreach ($field in @('endpoint','api_key')) {
        $envName = Get-EnvName -Value ([string](Get-Prop -Entry $Entry -Name $field))
        if (-not $envName) { continue }

        if ($provider -eq 'openrouter' -and $field -eq 'endpoint') { continue }
        if ($provider -eq 'ollama') { continue }
        $required.Add($envName) | Out-Null
    }

    return @($required | Select-Object -Unique)
}

function Test-EntryEnvUsable {
    param($Entry)
    $missing = @()
    foreach ($name in Get-RequiredEnvNamesForEntry -Entry $Entry) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { $missing += $name }
    }
    return [pscustomobject][ordered]@{
        usable = ($missing.Count -eq 0)
        missing = $missing
    }
}

function Get-HostNameFromInputs {
    param([string]$Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { return $Explicit }

    $preferencePath = Join-Path $HOME '.kbframework\host_preference.yaml'
    if (Test-Path -LiteralPath $preferencePath -PathType Leaf) {
        try {
            $text = Get-Content -LiteralPath $preferencePath -Raw -Encoding UTF8
            if ($text -match '(?im)^\s*host\s*:\s*([A-Za-z0-9_\-]+)\s*$') {
                $candidate = $matches[1]
                if ($candidate -in @('copilot-cli','opencode')) { return $candidate }
            }
        } catch { }
    }

    foreach ($envName in @('KB_FRAMEWORK_HOST','KB_HOST','FRAMEWORK_HOST')) {
        $candidate = [Environment]::GetEnvironmentVariable($envName)
        if ($candidate -in @('copilot-cli','opencode')) { return $candidate }
    }

    return 'copilot-cli'
}

function Initialize-ScratchRoot {
    if (-not (Test-Path -LiteralPath $Script:ScratchRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $Script:ScratchRoot -Force | Out-Null
    }
}

function New-ScratchPath {
    param([Parameter(Mandatory=$true)][string]$Leaf)
    Initialize-ScratchRoot
    return (Join-Path $Script:ScratchRoot $Leaf)
}

function Write-Utf8FileAtomic {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent)) { $parent = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temp = Join-Path $parent ('.' + (Split-Path -Leaf $Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllText($temp, $Content, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temp -Destination $Path -Force
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-HandleThroughScript {
    param(
        [Parameter(Mandatory=$true)][string]$HandleName,
        [Parameter(Mandatory=$true)][string]$ResolvedRegistryPath
    )

    if (-not (Test-Path -LiteralPath $Script:ResolverPath -PathType Leaf)) {
        throw "Resolve-Model.ps1 not found: $Script:ResolverPath"
    }

    $outPath = New-ScratchPath -Leaf ('resolve-' + ($HandleName -replace '[^A-Za-z0-9_.-]','_') + '-' + [guid]::NewGuid().ToString('N') + '.json')
    $output = & $Script:ResolverPath -Handle $HandleName -RegistryPath $ResolvedRegistryPath -OutPath $outPath 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Resolve-Model.ps1 failed for handle '$HandleName': $($output -join ' ')"
    }
    if (-not (Test-Path -LiteralPath $outPath -PathType Leaf)) {
        throw "Resolve-Model.ps1 did not write expected output for handle '$HandleName': $outPath"
    }
    $json = Get-Content -LiteralPath $outPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $json | Add-Member -NotePropertyName handle -NotePropertyValue $HandleName -Force
    return $json
}

function Get-DispatchPathForProvider {
    param([Parameter(Mandatory=$true)][string]$Provider)
    $path = Join-Path (Join-Path $Script:AdaptersRoot $Provider) 'dispatch.ps1'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Dispatch adapter not found for provider '$Provider': $path" }
    return $path
}

function New-DispatchJobSpec {
    param(
        [Parameter(Mandatory=$true)]$Resolved,
        [Parameter(Mandatory=$true)][string]$PromptText,
        [Parameter(Mandatory=$true)][string]$Tag
    )

    $promptPath = New-ScratchPath -Leaf ('prompt-' + $Tag + '-' + [guid]::NewGuid().ToString('N') + '.txt')
    $outPath = New-ScratchPath -Leaf ('dispatch-' + $Tag + '-' + [guid]::NewGuid().ToString('N') + '.json')
    Set-Content -LiteralPath $promptPath -Value $PromptText -Encoding UTF8

    return [pscustomobject][ordered]@{
        Handle = [string]$Resolved.handle
        Provider = [string]$Resolved.provider
        Family = [string]$Resolved.family
        ModelId = [string]$Resolved.model_id
        DispatchPath = Get-DispatchPathForProvider -Provider ([string]$Resolved.provider)
        PromptPath = $promptPath
        OutPath = $outPath
    }
}

function Read-DispatchOutput {
    param(
        [Parameter(Mandatory=$true)]$RunResult
    )

    $json = $null
    $completion = ''
    $schemaStatus = 'FAIL'
    $schemaEvidence = ''

    if ($RunResult.exit_code -ne 0) {
        return [pscustomobject][ordered]@{
            status = 'FAIL'
            schema_status = 'FAIL'
            completion = ''
            evidence = "dispatch exit_code=$($RunResult.exit_code); $($RunResult.stdout)"
            json = $null
        }
    }

    if (-not (Test-Path -LiteralPath $RunResult.out_path -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            status = 'FAIL'
            schema_status = 'FAIL'
            completion = ''
            evidence = "dispatch exited 0 but did not write output: $($RunResult.out_path)"
            json = $null
        }
    }

    try {
        $json = Get-Content -LiteralPath $RunResult.out_path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return [pscustomobject][ordered]@{
            status = 'WARN'
            schema_status = 'WARN'
            completion = ''
            evidence = "dispatch output was not parseable JSON: $($_.Exception.Message)"
            json = $null
        }
    }

    if ($json.PSObject.Properties['completion']) { $completion = [string]$json.completion }
    elseif ($json.PSObject.Properties['host_invocation']) { $completion = [string]$json.host_invocation.parameters.prompt }

    $hasCompletion = -not [string]::IsNullOrWhiteSpace($completion)
    $hasUsage = ($null -ne $json.PSObject.Properties['usage'])
    $hasCost = ($null -ne $json.PSObject.Properties['cost_estimate'])
    $statusValue = if ($json.PSObject.Properties['status']) { [string]$json.status } else { '' }

    if ($statusValue -eq 'error') {
        $schemaStatus = 'FAIL'
        $schemaEvidence = 'adapter returned status=error.'
    } elseif ($hasCompletion -and $hasUsage -and $hasCost) {
        $schemaStatus = 'PASS'
        $schemaEvidence = 'completion, usage, and cost_estimate fields present.'
    } elseif ($hasCompletion -and $hasUsage) {
        $schemaStatus = 'WARN'
        $schemaEvidence = 'completion and usage present, but cost_estimate missing.'
    } elseif ($statusValue -eq 'ready' -and $json.PSObject.Properties['host_invocation']) {
        $schemaStatus = 'WARN'
        $schemaEvidence = 'adapter emitted a host task envelope, not a completed live response.'
    } else {
        $schemaStatus = 'WARN'
        $schemaEvidence = 'dispatch completed, but completion/usage/cost schema was incomplete.'
    }

    return [pscustomobject][ordered]@{
        status = $schemaStatus
        schema_status = $schemaStatus
        completion = $completion
        evidence = $schemaEvidence
        json = $json
    }
}

function Invoke-DispatchJobSpecs {
    param(
        [Parameter(Mandatory=$true)][object[]]$Jobs,
        [Parameter(Mandatory=$false)][int]$ThrottleLimit = 4
    )

    return @($Jobs | ForEach-Object -Parallel {
        $job = $_
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $output = @()
        $exitCode = 1
        try {
            if ($job.Provider -eq 'copilot-cli') {
                $output = & $job.DispatchPath -ModelId $job.ModelId -PromptPath $job.PromptPath -OutPath $job.OutPath *>&1
            } else {
                $output = & $job.DispatchPath -ModelId $job.ModelId -PromptPath $job.PromptPath -OutPath $job.OutPath -MaxTokens 1 -Temperature 0 *>&1
            }
            $exitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
        } catch {
            $output += $_.Exception.Message
            $exitCode = 1
        }
        $sw.Stop()
        [pscustomobject][ordered]@{
            handle = $job.Handle
            provider = $job.Provider
            family = $job.Family
            model_id = $job.ModelId
            out_path = $job.OutPath
            exit_code = $exitCode
            stdout = ($output -join "`n")
            elapsed_seconds = [math]::Round($sw.Elapsed.TotalSeconds, 3)
        }
    } -ThrottleLimit $ThrottleLimit)
}

function Get-UsableRegistryEntries {
    param([Parameter(Mandatory=$true)][object[]]$Models)
    return @($Models | Where-Object {
        $handleName = [string](Get-Prop -Entry $_ -Name 'handle')
        $provider = [string](Get-Prop -Entry $_ -Name 'provider')
        $modelId = [string](Get-Prop -Entry $_ -Name 'model_id')
        if ([string]::IsNullOrWhiteSpace($handleName) -or [string]::IsNullOrWhiteSpace($provider) -or [string]::IsNullOrWhiteSpace($modelId)) { return $false }
        (Test-EntryEnvUsable -Entry $_).usable
    })
}

function Get-RegistryEntryByHandle {
    param([Parameter(Mandatory=$true)][object[]]$Models, [Parameter(Mandatory=$true)][string]$HandleName)
    return @($Models | Where-Object { [string](Get-Prop -Entry $_ -Name 'handle') -eq $HandleName } | Select-Object -First 1)
}

function Test-FileReadAbsolutePaths {
    $ErrorActionPreference = 'Stop'
    try {
        $scriptPath = $PSCommandPath
        if ([string]::IsNullOrWhiteSpace($scriptPath)) { $scriptPath = $MyInvocation.MyCommand.Path }
        $scriptPath = (Resolve-Path -LiteralPath $scriptPath).Path
        $scriptContent = Get-Content -LiteralPath $scriptPath -Raw -Encoding UTF8

        $contractPath = Join-Path $Script:FrameworkRoot 'HOST-CONTRACT.md'
        $contractContent = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8
        $contractLooksRight = ($contractContent -match 'HOST-CONTRACT\.md|Host Contract') -and ($contractContent -match '### 2\.1 File-read with absolute paths') -and ($contractContent -match '### 2\.5 Parallel sub-agent dispatch')

        if (-not [string]::IsNullOrWhiteSpace($scriptContent) -and $contractLooksRight) {
            Add-CheckResult -Number 1 -Check 'File-read absolute paths' -Status 'PASS' -Evidence "Read self ($($scriptContent.Length) chars) and HOST-CONTRACT.md via absolute paths."
        } else {
            Add-CheckResult -Number 1 -Check 'File-read absolute paths' -Status 'FAIL' -Evidence 'Absolute reads completed, but content expectation failed.'
        }
    } catch {
        Add-CheckResult -Number 1 -Check 'File-read absolute paths' -Status 'FAIL' -Evidence $_.Exception.Message
    }
}

function Test-FileWriteAtomicity {
    $ErrorActionPreference = 'Stop'
    $targetPath = $null
    $tempPath = $null
    try {
        Initialize-ScratchRoot
        $unique = [guid]::NewGuid().ToString('N')
        $targetPath = Join-Path $Script:ScratchRoot "validate-host-atomic-$unique.txt"
        $tempPath = Join-Path $Script:ScratchRoot ".validate-host-atomic-$unique.tmp"
        $content = "validate-host-atomic-$unique`n"

        if (Test-Path -LiteralPath $targetPath) { throw "Unique target path already existed: $targetPath" }
        [System.IO.File]::WriteAllText($tempPath, $content, [System.Text.UTF8Encoding]::new($false))
        $targetExistedBeforeMove = Test-Path -LiteralPath $targetPath
        Move-Item -LiteralPath $tempPath -Destination $targetPath -Force
        $readBack = Get-Content -LiteralPath $targetPath -Raw -Encoding UTF8
        $tempStillExists = Test-Path -LiteralPath $tempPath

        if ($readBack -ne $content) {
            Add-CheckResult -Number 2 -Check 'File-write + atomicity' -Status 'FAIL' -Evidence 'Write/read-back content mismatch.'
        } elseif ($targetExistedBeforeMove -or $tempStillExists) {
            Add-CheckResult -Number 2 -Check 'File-write + atomicity' -Status 'WARN' -Evidence "Write succeeded, but atomic sibling-temp evidence was incomplete. targetExistedBeforeMove=$targetExistedBeforeMove tempStillExists=$tempStillExists"
        } else {
            Add-CheckResult -Number 2 -Check 'File-write + atomicity' -Status 'PASS' -Evidence "Wrote sibling temp file and replaced target with Move-Item -Force; read-back matched; temp path did not remain as target."
        }
    } catch {
        Add-CheckResult -Number 2 -Check 'File-write + atomicity' -Status 'FAIL' -Evidence $_.Exception.Message
    } finally {
        if ($targetPath) { Remove-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue }
        if ($tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
    }
}

function Test-ShellExecution {
    $ErrorActionPreference = 'Stop'
    try {
        $version = $PSVersionTable.PSVersion
        if ($version.Major -lt 7) {
            Add-CheckResult -Number 3 -Check 'Shell exec PS 7+' -Status 'FAIL' -Evidence "Current PowerShell version is $version; HOST-CONTRACT requires PowerShell 7+."
            return
        }

        $dateOutput = & { Get-Date -Format o }
        if ($dateOutput -match '^\d{4}-\d{2}-\d{2}T') {
            Add-CheckResult -Number 3 -Check 'Shell exec PS 7+' -Status 'PASS' -Evidence "PowerShell $version; Get-Date command returned ISO-shaped output."
        } else {
            Add-CheckResult -Number 3 -Check 'Shell exec PS 7+' -Status 'WARN' -Evidence "PowerShell $version, but Get-Date output was unexpected: $dateOutput"
        }
    } catch {
        Add-CheckResult -Number 3 -Check 'Shell exec PS 7+' -Status 'FAIL' -Evidence $_.Exception.Message
    }
}

function Test-SingleDispatch {
    param(
        [Parameter(Mandatory=$true)][object[]]$Models,
        [Parameter(Mandatory=$true)][string]$ResolvedRegistryPath
    )

    if ($SkipLiveDispatch) {
        $Script:LiveDispatchTested = $false
        $Script:LiveDispatchExplanation = 'no — skipped by -SkipLiveDispatch'
        Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'SKIPPED' -Evidence 'Skipped by -SkipLiveDispatch.'
        return
    }

    try {
        $entry = $null
        if (-not [string]::IsNullOrWhiteSpace($Handle)) {
            $found = Get-RegistryEntryByHandle -Models $Models -HandleName $Handle
            if ($found.Count -eq 0) {
                Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'SKIPPED' -Evidence "Requested handle not found in registry: $Handle"
                $Script:LiveDispatchExplanation = "no — requested handle '$Handle' not found"
                return
            }
            $envResult = Test-EntryEnvUsable -Entry $found[0]
            if (-not $envResult.usable) {
                Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'SKIPPED' -Evidence "Requested handle '$Handle' is missing env vars: $($envResult.missing -join ', ')"
                $Script:LiveDispatchExplanation = "no — requested handle missing env vars"
                return
            }
            $entry = $found[0]
        } else {
            $usable = @(Get-UsableRegistryEntries -Models $Models)
            if ($usable.Count -eq 0) {
                Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'SKIPPED' -Evidence 'No usable registry handle had its required env vars present.'
                $Script:LiveDispatchExplanation = 'no — no usable registry handle with required env vars present'
                return
            }
            $entry = $usable[0]
        }

        $handleName = [string](Get-Prop -Entry $entry -Name 'handle')
        $resolved = Resolve-HandleThroughScript -HandleName $handleName -ResolvedRegistryPath $ResolvedRegistryPath
        $Script:SelectedHandle = $handleName
        $Script:SelectedResolvedHandle = $resolved
        $job = New-DispatchJobSpec -Resolved $resolved -PromptText "Respond with the word 'ping' and nothing else." -Tag 'single'

        $runStarted = Get-Date
        $result = @(Invoke-DispatchJobSpecs -Jobs @($job) -ThrottleLimit 1)[0]
        $Script:SingleDispatchSeconds = [double]$result.elapsed_seconds
        $parsed = Read-DispatchOutput -RunResult $result
        $Script:LiveDispatchTested = $true
        $Script:LiveDispatchExplanation = "yes — handle $handleName ($($resolved.provider)/$($resolved.model_id), family $($resolved.family))"

        $evidence = "handle=$handleName provider=$($resolved.provider) family=$($resolved.family) model=$($resolved.model_id) elapsed=$($result.elapsed_seconds)s; $($parsed.evidence)"
        if ($parsed.status -eq 'PASS') {
            Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'PASS' -Evidence $evidence -Data @{ started_at = $runStarted.ToString('o'); output_path = $result.out_path }
        } elseif ($parsed.status -eq 'WARN') {
            Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'WARN' -Evidence $evidence -Data @{ started_at = $runStarted.ToString('o'); output_path = $result.out_path }
        } else {
            Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'FAIL' -Evidence $evidence -Data @{ started_at = $runStarted.ToString('o'); output_path = $result.out_path }
        }
    } catch {
        Add-CheckResult -Number 4 -Check 'Sub-agent dispatch w/ handle' -Status 'FAIL' -Evidence $_.Exception.Message
        $Script:LiveDispatchTested = $true
        $Script:LiveDispatchExplanation = 'yes — attempted but failed'
    }
}

function Test-FourWayParallelDispatch {
    if ($SkipLiveDispatch) {
        Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'SKIPPED' -Evidence 'Skipped by -SkipLiveDispatch.'
        return
    }
    if ($null -eq $Script:SelectedResolvedHandle) {
        Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'SKIPPED' -Evidence 'Skipped because Check 4 did not select a usable handle.'
        return
    }
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'FAIL' -Evidence 'ForEach-Object -Parallel requires PowerShell 7+.'
        return
    }

    try {
        $jobs = @()
        for ($i = 1; $i -le 4; $i++) {
            $jobs += New-DispatchJobSpec -Resolved $Script:SelectedResolvedHandle -PromptText "Respond with exactly 'ping-$i' and nothing else." -Tag "parallel-$i"
        }

        $wallClock = [System.Diagnostics.Stopwatch]::StartNew()
        $runResults = @(Invoke-DispatchJobSpecs -Jobs $jobs -ThrottleLimit 4)
        $wallClock.Stop()
        $Script:Check5MaxConcurrencyObserved = $runResults.Count

        $parsed = @($runResults | ForEach-Object { Read-DispatchOutput -RunResult $_ })
        $failures = @($parsed | Where-Object { $_.status -eq 'FAIL' })
        $warnings = @($parsed | Where-Object { $_.status -eq 'WARN' })
        $wallSeconds = [math]::Round($wallClock.Elapsed.TotalSeconds, 3)
        $baseline = if ($null -ne $Script:SingleDispatchSeconds -and $Script:SingleDispatchSeconds -gt 0) { [double]$Script:SingleDispatchSeconds } else { [double](@($runResults | Measure-Object -Property elapsed_seconds -Average).Average) }
        $threshold = [math]::Max(2.0 * $baseline, 2.0)
        $timingParallel = ($wallSeconds -lt $threshold)
        $evidence = "completed=$($runResults.Count)/4 wall_clock=${wallSeconds}s single_call_baseline=$([math]::Round($baseline,3))s threshold=${threshold}s"

        if ($failures.Count -gt 0) {
            Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'FAIL' -Evidence "$evidence; failures=$($failures.Count)."
        } elseif (-not $timingParallel) {
            Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'WARN' -Evidence "$evidence; all returned, but timing suggests serialization."
        } elseif ($warnings.Count -gt 0) {
            Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'WARN' -Evidence "$evidence; all returned, but $($warnings.Count) output schema warning(s)."
        } else {
            Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'PASS' -Evidence "$evidence; all four dispatches returned successfully within parallel timing threshold."
        }
    } catch {
        Add-CheckResult -Number 5 -Check 'Parallel dispatch >=4' -Status 'FAIL' -Evidence $_.Exception.Message
    }
}

function Test-CrossFamilyParallelDispatch {
    param(
        [Parameter(Mandatory=$true)][object[]]$Models,
        [Parameter(Mandatory=$true)][string]$ResolvedRegistryPath
    )

    if ($SkipLiveDispatch) {
        Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'SKIPPED' -Evidence 'Skipped by -SkipLiveDispatch.'
        return
    }
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'FAIL' -Evidence 'ForEach-Object -Parallel requires PowerShell 7+.'
        return
    }

    try {
        $usable = @(Get-UsableRegistryEntries -Models $Models)
        if ($usable.Count -lt 2) {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'SKIPPED' -Evidence 'Fewer than two usable handles with required env vars present.'
            return
        }

        $selected = New-Object System.Collections.Generic.List[object]
        $families = @{}
        if ($null -ne $Script:SelectedResolvedHandle -and -not [string]::IsNullOrWhiteSpace([string]$Script:SelectedResolvedHandle.family)) {
            $selected.Add($Script:SelectedResolvedHandle) | Out-Null
            $families[[string]$Script:SelectedResolvedHandle.family] = $true
        }
        foreach ($entry in $usable) {
            $handleName = [string](Get-Prop -Entry $entry -Name 'handle')
            if ($selected | Where-Object { $_.handle -eq $handleName }) { continue }
            $family = [string](Get-Prop -Entry $entry -Name 'family')
            if ($families.ContainsKey($family)) { continue }
            $resolved = Resolve-HandleThroughScript -HandleName $handleName -ResolvedRegistryPath $ResolvedRegistryPath
            $selected.Add($resolved) | Out-Null
            $families[[string]$resolved.family] = $true
            if ($selected.Count -ge 2) { break }
        }

        if ($selected.Count -lt 2) {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'SKIPPED' -Evidence 'Fewer than two distinct model families available among usable handles.'
            return
        }

        $first = $selected[0]
        $second = $selected[1]
        $Script:Check6FamiliesTested = @([string]$first.family, [string]$second.family)
        $jobs = @(
            (New-DispatchJobSpec -Resolved $first -PromptText "Respond with exactly '$($first.family)-ping' and nothing else." -Tag 'cross-family-1'),
            (New-DispatchJobSpec -Resolved $second -PromptText "Respond with exactly '$($second.family)-ping' and nothing else." -Tag 'cross-family-2')
        )

        $wallClock = [System.Diagnostics.Stopwatch]::StartNew()
        $runResults = @(Invoke-DispatchJobSpecs -Jobs $jobs -ThrottleLimit 2)
        $wallClock.Stop()
        $parsed = @($runResults | ForEach-Object { Read-DispatchOutput -RunResult $_ })
        $failures = @($parsed | Where-Object { $_.status -eq 'FAIL' })
        $warnings = @($parsed | Where-Object { $_.status -eq 'WARN' })
        $wallSeconds = [math]::Round($wallClock.Elapsed.TotalSeconds, 3)
        $sumIndividual = [double](@($runResults | Measure-Object -Property elapsed_seconds -Sum).Sum)
        $maxIndividual = [double](@($runResults | Measure-Object -Property elapsed_seconds -Maximum).Maximum)
        $parallelThreshold = [math]::Min(($sumIndividual * 0.85), ($maxIndividual + 2.0))
        if ($parallelThreshold -le 0) { $parallelThreshold = 2.0 }
        $timingParallel = ($wallSeconds -le $parallelThreshold)
        $completionValues = @($parsed | ForEach-Object { ([string]$_.completion).Trim() } | Where-Object { $_ })
        $differentResponses = (@($completionValues | Select-Object -Unique).Count -ge 2)
        $evidence = "families=$($Script:Check6FamiliesTested -join '+') wall_clock=${wallSeconds}s sum_individual=$([math]::Round($sumIndividual,3))s max_individual=$([math]::Round($maxIndividual,3))s"

        if ($failures.Count -gt 0) {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'FAIL' -Evidence "$evidence; failures=$($failures.Count)."
        } elseif (-not $differentResponses) {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'WARN' -Evidence "$evidence; both dispatches returned, but completion responses were not distinguishable."
        } elseif (-not $timingParallel) {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'WARN' -Evidence "$evidence; both dispatches returned, but timing suggests sequential execution."
        } elseif ($warnings.Count -gt 0) {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'WARN' -Evidence "$evidence; both dispatches returned, but $($warnings.Count) schema warning(s)."
        } else {
            Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'PASS' -Evidence "$evidence; both distinct-family dispatches returned distinguishable responses in parallel timing."
        }
    } catch {
        Add-CheckResult -Number 6 -Check 'Cross-family parallel' -Status 'FAIL' -Evidence $_.Exception.Message
    }
}

function Get-CapabilityVerdict {
    $minimumFailed = @($Script:Checks | Where-Object { $_.number -in @(1,2,3) -and $_.status -eq 'FAIL' })
    if ($minimumFailed.Count -gt 0) {
        return [pscustomobject][ordered]@{ level = 'INVALID'; indeterminate = $false; explanation = 'One or more minimum host capabilities (Checks 1-3) failed.' }
    }

    $liveSkipped = @($Script:Checks | Where-Object { $_.number -in @(4,5,6) -and $_.status -eq 'SKIPPED' })
    if ($liveSkipped.Count -gt 0) {
        return [pscustomobject][ordered]@{ level = 'INDETERMINATE'; indeterminate = $true; explanation = 'Live dispatch checks were skipped; rerun without -SkipLiveDispatch after configuring usable model credentials to determine L1/L2/L3.' }
    }

    $c4 = Get-CheckStatus -Number 4
    $c5 = Get-CheckStatus -Number 5
    $c6 = Get-CheckStatus -Number 6

    if ($c4 -eq 'FAIL') {
        return [pscustomobject][ordered]@{ level = 'L3'; indeterminate = $false; explanation = 'Sub-agent dispatch failed, so the host is runtime-limited to L3 for framework gating.' }
    }
    if ($c4 -eq 'PASS' -and $c5 -eq 'PASS' -and $c6 -eq 'PASS') {
        return [pscustomobject][ordered]@{ level = 'L1a'; indeterminate = $false; explanation = 'All six checks passed, including four-way and cross-family parallel dispatch.' }
    }
    if ($c4 -eq 'PASS' -and $c5 -eq 'PASS' -and $c6 -eq 'WARN') {
        return [pscustomobject][ordered]@{ level = 'L1b'; indeterminate = $false; explanation = 'Parallel dispatch passed, but cross-family parallel behavior was warning-level; treat as L1b until cross-family parallelism is clean.' }
    }
    if ($c4 -eq 'PASS' -and $c5 -eq 'PASS' -and $c6 -eq 'FAIL') {
        return [pscustomobject][ordered]@{ level = 'L1b'; indeterminate = $false; explanation = 'Four-way dispatch passed, but cross-family dispatch failed; host is parallel but not runtime-verified cross-family.' }
    }
    if ($c4 -in @('PASS','WARN')) {
        return [pscustomobject][ordered]@{ level = 'L2'; indeterminate = $false; explanation = 'Single dispatch works, but parallel or schema checks did not cleanly pass; model separation must be enforced sequentially.' }
    }

    return [pscustomobject][ordered]@{ level = 'L3'; indeterminate = $false; explanation = 'Live dispatch did not demonstrate model-switching capability.' }
}

function Update-HostNotesFile {
    param(
        [Parameter(Mandatory=$true)][string]$ResolvedHostName,
        [Parameter(Mandatory=$true)][string]$Level,
        [Parameter(Mandatory=$true)][string]$RunDate,
        [Parameter(Mandatory=$true)][object[]]$Checks
    )

    $notesPath = Join-Path $Script:FrameworkRoot "hosts\$ResolvedHostName\HOST-NOTES.md"
    if (-not (Test-Path -LiteralPath $notesPath -PathType Leaf)) { return "HOST-NOTES.md not found for host '$ResolvedHostName'; no update performed." }

    $dateOnly = (Get-Date).ToString('yyyy-MM-dd')
    $text = Get-Content -LiteralPath $notesPath -Raw -Encoding UTF8
    $changed = $false

    if ($text -match '(?im)^\*\*Declared level:\s*L[123][ab]?\s*[^\r\n]*\*\*\s*$') {
        $text = [regex]::Replace($text, '(?im)^\*\*Declared level:\s*L[123][ab]?\s*[^\r\n]*\*\*\s*$', "**Declared level: $Level — runtime verified via Validate-Host.ps1.**", 1)
        $changed = $true
    } elseif ($text -match '(?im)^#\s*Capability level:\s*L[123][ab]?\s*[^\r\n]*$') {
        $text = [regex]::Replace($text, '(?im)^#\s*Capability level:\s*L[123][ab]?\s*[^\r\n]*$', "# Capability level: $Level — runtime verified via Validate-Host.ps1", 1)
        $changed = $true
    } elseif ($text -match '(?im)^Declared capability level:\s*L[123][ab]?\s*[^\r\n]*$') {
        $text = [regex]::Replace($text, '(?im)^Declared capability level:\s*L[123][ab]?\s*[^\r\n]*$', "Declared capability level: $Level — runtime verified via Validate-Host.ps1", 1)
        $changed = $true
    }

    if ($text -match '(?im)^Last primary-source verification:\s*[^\r\n]*$') {
        $text = [regex]::Replace($text, '(?im)^Last primary-source verification:\s*[^\r\n]*$', "Last primary-source verification: $dateOnly (runtime verified via Validate-Host.ps1)  ", 1)
        $changed = $true
    } elseif ($text -match '(?im)^#\s*Last verification:\s*[^\r\n]*$') {
        $text = [regex]::Replace($text, '(?im)^#\s*Last verification:\s*[^\r\n]*$', "# Last verification: $dateOnly (runtime verified via Validate-Host.ps1)", 1)
        $changed = $true
    }

    if ($ResolvedHostName -eq 'opencode' -and $Level -eq 'L1a') {
        $replacement = "[VERIFIED-AT-RUNTIME $dateOnly via Validate-Host.ps1]"
        $text = $text -replace '\[NEEDS-VERIFICATION\]', $replacement
        $changed = $true
    }

    $historyRow = "| $dateOnly | $Level | Validate-Host.ps1 $Script:ValidateHostVersion | $($Checks.Count) checks; live dispatch tested: $($Script:LiveDispatchTested) |"
    if ($text -notmatch '(?im)^##\s+Runtime validation history\s*$') {
        $text = $text.TrimEnd() + "`r`n`r`n## Runtime validation history`r`n`r`n| Date | Verdict | Tool | Notes |`r`n|---|---|---|---|`r`n$historyRow`r`n"
    } else {
        $text = $text.TrimEnd() + "`r`n$historyRow`r`n"
    }
    $changed = $true

    if ($changed) {
        Write-Utf8FileAtomic -Path $notesPath -Content $text
        return "Updated $notesPath with runtime-verified level $Level and validation history row."
    }
    return "No matching HOST-NOTES fields were updated in $notesPath."
}

function New-MarkdownReport {
    param(
        [Parameter(Mandatory=$true)][string]$ResolvedHostName,
        [Parameter(Mandatory=$true)][string]$ResolvedRegistryPath,
        [Parameter(Mandatory=$true)]$Verdict,
        [Parameter(Mandatory=$true)][string]$RunDate,
        [Parameter(Mandatory=$true)][string]$HostNotesUpdateText
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Host Capability Validation Report') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("**Host:** $ResolvedHostName") | Out-Null
    $lines.Add("**Validate-Host version:** $Script:ValidateHostVersion") | Out-Null
    $lines.Add("**Run date:** $RunDate") | Out-Null
    $lines.Add("**PowerShell version:** $($PSVersionTable.PSVersion)") | Out-Null
    $lines.Add("**Registry:** $ResolvedRegistryPath") | Out-Null
    $lines.Add("**Live dispatch tested:** $Script:LiveDispatchExplanation") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Check results') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| # | Check | Status | Evidence |') | Out-Null
    $lines.Add('|---|---|---|---|') | Out-Null
    foreach ($check in ($Script:Checks | Sort-Object number)) {
        $lines.Add(('| {0} | {1} | {2} | {3} |' -f $check.number, (Escape-MarkdownCell $check.check), $check.status, (Escape-MarkdownCell $check.evidence))) | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Verdict') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("**Runtime-verified capability level: $($Verdict.level)**") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Verdict.explanation) | Out-Null
    if ($Script:SelectedHandle) { $lines.Add("Selected live handle: ``$($Script:SelectedHandle)``.") | Out-Null }
    if ($Script:Check5MaxConcurrencyObserved -gt 0) { $lines.Add("Max concurrency observed: $Script:Check5MaxConcurrencyObserved.") | Out-Null }
    if ($Script:Check6FamiliesTested.Count -gt 0) { $lines.Add("Model families tested together: $($Script:Check6FamiliesTested -join ', ').") | Out-Null }
    $lines.Add('') | Out-Null
    $lines.Add('## HOST-NOTES update') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($HostNotesUpdateText) | Out-Null
    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

if ($Help) {
    Show-Usage
    exit 0
}

$resolvedHostName = Get-HostNameFromInputs -Explicit $HostName
$runDate = (Get-Date).ToString('o')
$resolvedRegistry = $null
$hostNotesUpdateText = 'Not requested.'
$exitCode = 0

try {
    Initialize-ScratchRoot
    $resolvedRegistry = Resolve-RegistryPath -Path $RegistryPath
    $models = @(ConvertFrom-ModelRegistryYaml -Path $resolvedRegistry)

    Test-FileReadAbsolutePaths
    Test-FileWriteAtomicity
    Test-ShellExecution
    Test-SingleDispatch -Models $models -ResolvedRegistryPath $resolvedRegistry
    Test-FourWayParallelDispatch
    Test-CrossFamilyParallelDispatch -Models $models -ResolvedRegistryPath $resolvedRegistry

    $verdict = Get-CapabilityVerdict

    if ($UpdateHostNotes) {
        if ($verdict.level -in @('L1a','L1b','L2','L3')) {
            $hostNotesUpdateText = Update-HostNotesFile -ResolvedHostName $resolvedHostName -Level $verdict.level -RunDate $runDate -Checks $Script:Checks.ToArray()
        } else {
            $hostNotesUpdateText = "Update requested, but skipped because verdict is $($verdict.level)."
        }
    }

    $report = New-MarkdownReport -ResolvedHostName $resolvedHostName -ResolvedRegistryPath $resolvedRegistry -Verdict $verdict -RunDate $runDate -HostNotesUpdateText $hostNotesUpdateText

    if (-not [string]::IsNullOrWhiteSpace($OutPath)) {
        Write-Utf8FileAtomic -Path $OutPath -Content $report
        Write-Host "Validate-Host report written to $OutPath"
    } else {
        Write-Output $report
    }

    if ($verdict.level -eq 'INVALID') { $exitCode = 1 }
    elseif ($verdict.indeterminate) { $exitCode = 2 }
    else { $exitCode = 0 }
} catch {
    Write-Error $_.Exception.Message
    $exitCode = 1
} finally {
    Remove-Item -LiteralPath $Script:ScratchRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit $exitCode
