# Title: Resolve-Model.ps1 — Model Registry handle resolver.
# Purpose: Resolve a framework model handle to provider configuration.
# Inputs: -Handle plus optional -RegistryPath and -OutPath.
# Outputs: Hashtable on stdout, or JSON/YAML object at -OutPath.
# Exit codes: 0 success; 1 registry read error or handle not found.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Handle,
    [Parameter(Mandatory=$false)][string]$RegistryPath = (Join-Path $PSScriptRoot 'model-registry.yaml'),
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-RegistryPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return (Resolve-Path -LiteralPath $Path).Path }
    $example = Join-Path $PSScriptRoot 'model-registry.example.yaml'
    if ((Split-Path -Leaf $Path) -eq 'model-registry.yaml' -and (Test-Path -LiteralPath $example)) {
        Write-Warning "RegistryPath '$Path' not found; using model-registry.example.yaml for read-only resolution."
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

function Resolve-EnvReference {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -match '^env:([A-Za-z_][A-Za-z0-9_]*)$') {
        return [Environment]::GetEnvironmentVariable($matches[1])
    }
    return $Value
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
        $Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

try {
    $resolvedPath = Resolve-RegistryPath -Path $RegistryPath
    $models = @(ConvertFrom-ModelRegistryYaml -Path $resolvedPath)
    $entry = @($models | Where-Object { (Get-EntryValue -Entry $_ -Name 'handle') -eq $Handle } | Select-Object -First 1)
    if ($entry.Count -eq 0) {
        Write-Error "Model handle not found in registry '$resolvedPath': $Handle"
        exit 1
    }
    $entry = $entry[0]
    $result = [ordered]@{
        handle = [string](Get-EntryValue -Entry $entry -Name 'handle')
        provider = [string](Get-EntryValue -Entry $entry -Name 'provider')
        model_id = [string](Get-EntryValue -Entry $entry -Name 'model_id')
        endpoint = Resolve-EnvReference -Value ([string](Get-EntryValue -Entry $entry -Name 'endpoint'))
        api_key = Resolve-EnvReference -Value ([string](Get-EntryValue -Entry $entry -Name 'api_key'))
        family = [string](Get-EntryValue -Entry $entry -Name 'family')
        capabilities = @(Get-EntryValue -Entry $entry -Name 'capabilities')
        notes = [string](Get-EntryValue -Entry $entry -Name 'notes')
    }

    if ($OutPath) {
        Write-StructuredOutput -Data $result -Path $OutPath
        Write-Host "Resolved handle '$Handle' to '$($result.provider)/$($result.model_id)' and wrote structured output to $OutPath"
    } else {
        Write-Output $result
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

