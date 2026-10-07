# Title: Refresh-Registry.ps1 — provider catalog drift reporter.
# Purpose: Compare Model Registry entries to provider discover.ps1 catalogs.
# Inputs: Optional -RegistryPath, -AdaptersRoot, -CachePath, and -OutPath.
# Outputs: Human-readable drift report, or JSON/YAML report at -OutPath.
# Exit codes: 0 report generated; 1 registry read or report-write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$RegistryPath = (Join-Path $PSScriptRoot 'model-registry.yaml'),
    [Parameter(Mandatory=$false)][string]$AdaptersRoot = (Join-Path $PSScriptRoot 'adapters\model-providers'),
    [Parameter(Mandatory=$false)][string]$CachePath = (Join-Path $PSScriptRoot 'audit-templates\openrouter-categories.cached.yaml'),
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-RegistryPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return (Resolve-Path -LiteralPath $Path).Path }
    $example = Join-Path $PSScriptRoot 'model-registry.example.yaml'
    if ((Split-Path -Leaf $Path) -eq 'model-registry.yaml' -and (Test-Path -LiteralPath $example)) {
        Write-Warning "RegistryPath '$Path' not found; using model-registry.example.yaml for refresh report."
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
    param([string]$Path)
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
    return $models
}

function Get-EntryValue {
    param($Entry, [string]$Name)
    $prop = $Entry.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
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

function Get-CatalogModels {
    param($DiscoverOutput)
    $items = @()
    if ($null -eq $DiscoverOutput) { return @() }
    if ($DiscoverOutput.PSObject.Properties['models']) { $items = @($DiscoverOutput.models) }
    elseif ($DiscoverOutput -is [System.Collections.IEnumerable] -and -not ($DiscoverOutput -is [string])) { $items = @($DiscoverOutput) }
    else { $items = @($DiscoverOutput) }

    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($item in $items) {
        if ($item -is [string]) { $ids.Add($item) | Out-Null; continue }
        foreach ($propName in @('model_id','id','name')) {
            $prop = $item.PSObject.Properties[$propName]
            if ($prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                $ids.Add([string]$prop.Value) | Out-Null
                break
            }
        }
    }
    return @($ids | Select-Object -Unique)
}

function Invoke-DiscoverScript {
    param([string]$DiscoverPath)
    $output = & $DiscoverPath 2>&1
    if ($LASTEXITCODE -ne 0) { throw "discover.ps1 exited with ${LASTEXITCODE}: $($output -join ' ')" }
    $text = ($output | Out-String).Trim()
    if (-not $text) { return @() }
    try { return ($text | ConvertFrom-Json) } catch { throw "discover.ps1 did not emit parseable JSON. Output: $text" }
}

try {
    $resolvedRegistry = Resolve-RegistryPath -Path $RegistryPath
    $models = @(ConvertFrom-ModelRegistryYaml -Path $resolvedRegistry)
    $providers = @($models | ForEach-Object { [string](Get-EntryValue -Entry $_ -Name 'provider') } | Where-Object { $_ } | Select-Object -Unique)
    $providerReports = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[string]

    foreach ($provider in $providers) {
        $adapterDir = Join-Path $AdaptersRoot $provider
        $discoverPath = Join-Path $adapterDir 'discover.ps1'
        $registered = @($models | Where-Object { [string](Get-EntryValue -Entry $_ -Name 'provider') -eq $provider })
        $registeredIds = @($registered | ForEach-Object { [string](Get-EntryValue -Entry $_ -Name 'model_id') } | Where-Object { $_ } | Select-Object -Unique)
        $report = [ordered]@{
            provider = $provider
            adapter_dir = $adapterDir
            discover = $discoverPath
            status = 'skipped'
            registered_model_ids = $registeredIds
            catalog_model_ids = @()
            new_models = @()
            stale_registry_entries = @()
            warnings = @()
        }

        if (-not (Test-Path -LiteralPath $adapterDir -PathType Container)) {
            $message = "Provider adapter directory missing for '$provider'; skipping discovery. Expected: $adapterDir"
            $report.warnings = @($message)
            $warnings.Add($message) | Out-Null
            $providerReports.Add([pscustomobject]$report) | Out-Null
            continue
        }
        if (-not (Test-Path -LiteralPath $discoverPath -PathType Leaf)) {
            $message = "discover.ps1 missing for '$provider'; skipping until L1b-e adapters are implemented."
            $report.warnings = @($message)
            $warnings.Add($message) | Out-Null
            $providerReports.Add([pscustomobject]$report) | Out-Null
            continue
        }

        try {
            $catalog = Invoke-DiscoverScript -DiscoverPath $discoverPath
            $catalogIds = @(Get-CatalogModels -DiscoverOutput $catalog)
            $newModels = @($catalogIds | Where-Object { $registeredIds -notcontains $_ })
            $stale = @($registered | Where-Object { $catalogIds -notcontains ([string](Get-EntryValue -Entry $_ -Name 'model_id')) } | ForEach-Object {
                [pscustomobject]@{ handle = [string](Get-EntryValue -Entry $_ -Name 'handle'); model_id = [string](Get-EntryValue -Entry $_ -Name 'model_id') }
            })
            $report.status = 'ok'
            $report.catalog_model_ids = $catalogIds
            $report.new_models = $newModels
            $report.stale_registry_entries = $stale
        } catch {
            $report.status = 'error'
            $message = "Discovery failed for '$provider': $($_.Exception.Message)"
            $report.warnings = @($message)
            $warnings.Add($message) | Out-Null
        }
        $providerReports.Add([pscustomobject]$report) | Out-Null
    }

    $openRouterCacheStatus = 'not-applicable'
    if ($providers -contains 'openrouter') {
        $categoryScript = Join-Path $PSScriptRoot 'Discover-OpenRouterCategories.ps1'
        if (Test-Path -LiteralPath $categoryScript -PathType Leaf) {
            try {
                & $categoryScript -OutPath $CachePath | Out-Null
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                    $openRouterCacheStatus = "updated: $CachePath"
                } else {
                    $openRouterCacheStatus = "update failed: Discover-OpenRouterCategories.ps1 exited with $LASTEXITCODE"
                    $warnings.Add($openRouterCacheStatus) | Out-Null
                }
            } catch {
                $openRouterCacheStatus = "update failed: $($_.Exception.Message)"
                $warnings.Add($openRouterCacheStatus) | Out-Null
            }
        } else {
            $openRouterCacheStatus = 'skipped: Discover-OpenRouterCategories.ps1 not implemented yet'
            $warnings.Add($openRouterCacheStatus) | Out-Null
        }
    }

    $result = [ordered]@{
        registry = $resolvedRegistry
        adapters_root = $AdaptersRoot
        checked_at = (Get-Date).ToString('s')
        providers = $providerReports.ToArray()
        openrouter_categories_cache = $openRouterCacheStatus
        warnings = $warnings.ToArray()
    }

    if ($OutPath) {
        Write-StructuredOutput -Data $result -Path $OutPath
        Write-Host "Registry refresh report written to $OutPath"
    } else {
        Write-Host '# Model Registry Refresh Report'
        Write-Host "Registry: $resolvedRegistry"
        Write-Host "Checked: $($result.checked_at)"
        Write-Host ''
        foreach ($providerReport in $providerReports) {
            Write-Host "## $($providerReport.provider) — $($providerReport.status)"
            if ($providerReport.warnings.Count -gt 0) {
                foreach ($warning in $providerReport.warnings) { Write-Host "- WARNING: $warning" }
            }
            if ($providerReport.status -eq 'ok') {
                Write-Host "- Registered models: $($providerReport.registered_model_ids.Count)"
                Write-Host "- Catalog models: $($providerReport.catalog_model_ids.Count)"
                if ($providerReport.new_models.Count -gt 0) {
                    Write-Host '- New models available to consider:'
                    foreach ($id in $providerReport.new_models) { Write-Host "  - $id" }
                } else { Write-Host '- New models available to consider: none' }
                if ($providerReport.stale_registry_entries.Count -gt 0) {
                    Write-Host '- Registry entries missing from provider catalog:'
                    foreach ($entry in $providerReport.stale_registry_entries) { Write-Host "  - $($entry.handle): $($entry.model_id)" }
                } else { Write-Host '- Registry entries missing from provider catalog: none' }
            }
            Write-Host ''
        }
        Write-Host "OpenRouter category cache: $openRouterCacheStatus"
    }

    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

