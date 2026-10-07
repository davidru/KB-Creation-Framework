# Title: Validate-ModelRegistry.ps1 — Model Registry schema validator.
# Purpose: Validate model-registry.yaml/example files and adapter/env readiness.
# Inputs: -RegistryPath or -RegistryContent, optional -SchemaPath and -OutPath.
# Outputs: Human report on stdout, or JSON/YAML validation report at -OutPath.
# Exit codes: 0 schema valid; 1 registry/schema errors.
[CmdletBinding(DefaultParameterSetName='Path')]
param(
    [Parameter(Mandatory=$false, ParameterSetName='Path')][string]$RegistryPath = (Join-Path $PSScriptRoot 'model-registry.yaml'),
    [Parameter(Mandatory=$true, ParameterSetName='Content')][string]$RegistryContent,
    [Parameter(Mandatory=$false)][string]$SchemaPath = (Join-Path $PSScriptRoot 'audit-templates\model-registry.schema.json'),
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-RegistryPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return (Resolve-Path -LiteralPath $Path).Path }
    $example = Join-Path $PSScriptRoot 'model-registry.example.yaml'
    if ((Split-Path -Leaf $Path) -eq 'model-registry.yaml' -and (Test-Path -LiteralPath $example)) {
        Write-Warning "RegistryPath '$Path' not found; using model-registry.example.yaml for validation."
        return (Resolve-Path -LiteralPath $example).Path
    }
    throw "RegistryPath not found: $Path"
}

function ConvertFrom-RegistryYamlValue {
    param([string]$Value)
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
    param([string[]]$Lines)
    $models = @()
    $current = $null
    $inModels = $false
    foreach ($raw in $Lines) {
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
    return $models
}

function Get-EntryValue {
    param($Entry, [string]$Name)
    $prop = $Entry.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function Get-EnvRefName {
    param([string]$Value)
    if ($Value -match '^env:([A-Za-z_][A-Za-z0-9_]*)$') { return $matches[1] }
    return $null
}

function Test-Scalar {
    param($Value)
    return ($null -eq $Value) -or ($Value -is [string]) -or ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [bool])
}

function Format-YamlScalar {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) { return [string]$Value }
    $text = [string]$Value
    if ($text -match '[:#\[\]{},&*?]|^\s|\s$|^$') { return '"' + ($text -replace '"','\"') + '"' }
    return $text
}

function ConvertTo-SimpleYaml {
    param($Value, [int]$Indent = 0)
    $spaces = ' ' * $Indent
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Scalar $Value) {
        $lines.Add(($spaces + (Format-YamlScalar $Value))) | Out-Null
    } elseif ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $item = $Value[$key]
            if (Test-Scalar $item) {
                $lines.Add(('{0}{1}: {2}' -f $spaces, $key, (Format-YamlScalar $item))) | Out-Null
            } else {
                $lines.Add(('{0}{1}:' -f $spaces, $key)) | Out-Null
                foreach ($line in ConvertTo-SimpleYaml -Value $item -Indent ($Indent + 2)) { $lines.Add($line) | Out-Null }
            }
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            if (Test-Scalar $item) {
                $lines.Add(('{0}- {1}' -f $spaces, (Format-YamlScalar $item))) | Out-Null
            } else {
                $lines.Add(('{0}-' -f $spaces)) | Out-Null
                foreach ($line in ConvertTo-SimpleYaml -Value $item -Indent ($Indent + 2)) { $lines.Add($line) | Out-Null }
            }
        }
    } else {
        $map = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) { $map[$prop.Name] = $prop.Value }
        foreach ($line in ConvertTo-SimpleYaml -Value $map -Indent $Indent) { $lines.Add($line) | Out-Null }
    }
    return @($lines)
}

function Write-StructuredOutput {
    param($Data, [string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ($Path -match '\.ya?ml$') {
        (ConvertTo-SimpleYaml -Value $Data) -join [Environment]::NewLine | Set-Content -LiteralPath $Path -Encoding UTF8
    } else {
        $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

try {
    if (-not (Test-Path -LiteralPath $SchemaPath)) { throw "SchemaPath not found: $SchemaPath" }
    $schema = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $entrySchema = $schema.'$defs'.modelRegistryEntry
    $required = @($entrySchema.required)
    $familyEnum = @($entrySchema.properties.family.enum)
    $providerEnum = @($entrySchema.properties.provider.enum)

    $sourceLabel = 'inline registry content'
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $resolvedPath = Resolve-RegistryPath -Path $RegistryPath
        $sourceLabel = $resolvedPath
        $lines = @(Get-Content -LiteralPath $resolvedPath -Encoding UTF8)
    } else {
        $lines = @($RegistryContent -split "`r?`n")
    }

    $models = @(ConvertFrom-ModelRegistryYaml -Lines $lines)
    $errors = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    $handleStatuses = New-Object System.Collections.Generic.List[object]

    if ($models.Count -eq 0) {
        $errors.Add([pscustomobject]@{ scope='registry'; message='Registry must contain a non-empty models array/list.' }) | Out-Null
    }

    $seenHandles = @{}
    foreach ($entry in $models) {
        $handle = [string](Get-EntryValue -Entry $entry -Name 'handle')
        $displayHandle = if ($handle) { $handle } else { '<missing-handle>' }
        foreach ($field in $required) {
            $value = Get-EntryValue -Entry $entry -Name $field
            if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
                $errors.Add([pscustomobject]@{ scope=$displayHandle; message="Missing required field '$field'." }) | Out-Null
            }
        }

        if ($handle) {
            if ($seenHandles.ContainsKey($handle)) {
                $errors.Add([pscustomobject]@{ scope=$handle; message='Duplicate handle; handles must be unique.' }) | Out-Null
            } else {
                $seenHandles[$handle] = $true
            }
            if ($handle -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
                $errors.Add([pscustomobject]@{ scope=$handle; message='Handle does not match schema pattern ^[A-Za-z0-9][A-Za-z0-9_.-]*$.' }) | Out-Null
            }
        }

        $family = [string](Get-EntryValue -Entry $entry -Name 'family')
        if ($family -and ($familyEnum -notcontains $family)) {
            $errors.Add([pscustomobject]@{ scope=$displayHandle; message="Family '$family' is not in schema enum: $($familyEnum -join ', ')." }) | Out-Null
        }
        $provider = [string](Get-EntryValue -Entry $entry -Name 'provider')
        if ($provider -and ($providerEnum -notcontains $provider)) {
            $errors.Add([pscustomobject]@{ scope=$displayHandle; message="Provider '$provider' is not in schema enum: $($providerEnum -join ', ')." }) | Out-Null
        }

        foreach ($envField in @('endpoint','api_key')) {
            $raw = [string](Get-EntryValue -Entry $entry -Name $envField)
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            $envName = Get-EnvRefName -Value $raw
            if (-not $envName) {
                $errors.Add([pscustomobject]@{ scope=$displayHandle; message="$envField must use env:VAR_NAME indirection." }) | Out-Null
                continue
            }
            if ($null -eq [Environment]::GetEnvironmentVariable($envName)) {
                $warnings.Add([pscustomobject]@{ scope=$displayHandle; message="Environment variable '$envName' declared by $envField is not present." }) | Out-Null
            }
        }

        if ($provider) {
            $adapterDir = Join-Path $PSScriptRoot (Join-Path 'adapters\model-providers' $provider)
            if (-not (Test-Path -LiteralPath $adapterDir -PathType Container)) {
                $warnings.Add([pscustomobject]@{ scope=$displayHandle; message="Provider adapter directory is not present yet: adapters\model-providers\$provider" }) | Out-Null
            }
        }

        $endpointRef = [string](Get-EntryValue -Entry $entry -Name 'endpoint')
        $apiKeyRef = [string](Get-EntryValue -Entry $entry -Name 'api_key')
        $endpointEnv = Get-EnvRefName -Value $endpointRef
        $apiKeyEnv = Get-EnvRefName -Value $apiKeyRef
        $schemaStatus = if (@($errors | Where-Object { $_.scope -eq $displayHandle }).Count -eq 0) { 'ok' } else { 'error' }
        $endpointPresent = if ($endpointEnv) { $null -ne [Environment]::GetEnvironmentVariable($endpointEnv) } else { $null }
        $apiKeyPresent = if ($apiKeyEnv) { $null -ne [Environment]::GetEnvironmentVariable($apiKeyEnv) } else { $null }
        $handleStatuses.Add([pscustomobject]@{
            handle = $displayHandle
            provider = $provider
            model_id = [string](Get-EntryValue -Entry $entry -Name 'model_id')
            family = $family
            schema_status = $schemaStatus
            endpoint_env = $endpointEnv
            endpoint_present = $endpointPresent
            api_key_env = $apiKeyEnv
            api_key_present = $apiKeyPresent
        }) | Out-Null
    }

    $adapterStatuses = foreach ($provider in ($models | ForEach-Object { [string](Get-EntryValue -Entry $_ -Name 'provider') } | Where-Object { $_ } | Select-Object -Unique)) {
        $path = Join-Path $PSScriptRoot (Join-Path 'adapters\model-providers' $provider)
        [pscustomobject]@{ provider=$provider; path=$path; exists=(Test-Path -LiteralPath $path -PathType Container) }
    }

    $verdict = if ($errors.Count -eq 0) { 'PASS' } else { 'FAIL' }
    $result = [ordered]@{
        registry = $sourceLabel
        schema = (Resolve-Path -LiteralPath $SchemaPath).Path
        verdict = $verdict
        error_count = $errors.Count
        warning_count = $warnings.Count
        errors = $errors.ToArray()
        warnings = $warnings.ToArray()
        adapters = @($adapterStatuses)
        handles = $handleStatuses.ToArray()
    }

    if ($OutPath) {
        Write-StructuredOutput -Data $result -Path $OutPath
        Write-Host "Model Registry validation $($result.verdict); wrote structured report to $OutPath"
    } else {
        Write-Host "Model Registry validation: $($result.verdict)"
        Write-Host "Registry: $sourceLabel"
        Write-Host "Handles checked: $($models.Count)"
        if ($errors.Count -gt 0) {
            Write-Host ''
            Write-Host 'Errors:'
            foreach ($err in $errors) { Write-Host "- [$($err.scope)] $($err.message)" }
        }
        if ($warnings.Count -gt 0) {
            Write-Host ''
            Write-Host 'Warnings (non-fatal):'
            foreach ($warn in $warnings) { Write-Host "- [$($warn.scope)] $($warn.message)" }
        }
        Write-Host ''
        Write-Host 'Per-handle resolution status:'
        foreach ($status in $handleStatuses) {
            Write-Host ("- {0}: {1}/{2} family={3} schema={4} endpoint_env={5} api_key_env={6}" -f $status.handle, $status.provider, $status.model_id, $status.family, $status.schema_status, $status.endpoint_env, $status.api_key_env)
        }
    }

    if ($errors.Count -gt 0) { exit 1 }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

