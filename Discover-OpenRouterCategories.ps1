# Title: Discover-OpenRouterCategories.ps1 — OpenRouter category cache prober.
# Purpose: Probe known/custom OpenRouter category names and cache non-empty results.
# Inputs: Optional -CustomCategory values and -OutPath for YAML/JSON structured output.
# Outputs: Human Markdown report or structured cache file at -OutPath.
# Exit codes: 0 cache generated; 1 probe/write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string[]]$CustomCategory = @(),
    [Parameter(Mandatory=$false)][string]$OutPath = (Join-Path $PSScriptRoot 'audit-templates\openrouter-categories.cached.yaml')
)

$ErrorActionPreference = 'Stop'
$OpenRouterBaseUri = 'https://openrouter.ai/api/v1'

function Test-Scalar { param($Value) return (($null -eq $Value) -or ($Value -is [string]) -or ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [decimal]) -or ($Value -is [bool])) }
function Format-YamlScalar {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return ([string]$Value) }
    $text = [string]$Value
    if ($text -eq '') { return '""' }
    if ($text -match '[:#\[\]{},&*?]|^\s|\s$|\|') { return '"' + ($text -replace '"','\"') + '"' }
    return $text
}
function ConvertTo-SimpleYaml {
    param($Value, [int]$Indent = 0)
    $spaces = ' ' * $Indent
    $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Scalar $Value) { $lines.Add($spaces + (Format-YamlScalar $Value)) | Out-Null }
    elseif ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $item = $Value[$key]
            if (Test-Scalar $item) { $lines.Add(('{0}{1}: {2}' -f $spaces, $key, (Format-YamlScalar $item))) | Out-Null }
            else { $lines.Add(('{0}{1}:' -f $spaces, $key)) | Out-Null; foreach ($line in ConvertTo-SimpleYaml -Value $item -Indent ($Indent + 2)) { $lines.Add($line) | Out-Null } }
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            if (Test-Scalar $item) { $lines.Add(('{0}- {1}' -f $spaces, (Format-YamlScalar $item))) | Out-Null }
            else { $lines.Add(('{0}-' -f $spaces)) | Out-Null; foreach ($line in ConvertTo-SimpleYaml -Value $item -Indent ($Indent + 2)) { $lines.Add($line) | Out-Null } }
        }
    } else {
        $map = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) { $map[$prop.Name] = $prop.Value }
        foreach ($line in ConvertTo-SimpleYaml -Value $map -Indent $Indent) { $lines.Add($line) | Out-Null }
    }
    return @($lines)
}
function Write-StructuredOutput { param($Data, [string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ($Path -match '\.ya?ml$') { (ConvertTo-SimpleYaml -Value $Data) -join [Environment]::NewLine | Set-Content -LiteralPath $Path -Encoding UTF8 }
    else { $Data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8 }
}
function Get-ModelCountForCategory {
    param([Parameter(Mandatory=$true)][string]$Category)
    $uri = "$OpenRouterBaseUri/models?category=$([System.Uri]::EscapeDataString($Category))"
    $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 45
    if ($response.PSObject.Properties['data']) { return @($response.data).Count }
    if ($response -is [System.Collections.IEnumerable] -and -not ($response -is [string])) { return @($response).Count }
    if ($null -eq $response) { return 0 }
    return 1
}

try {
    $defaultCategories = @('legal','programming','finance','science','academic','marketing','roleplay','translation','technology','general','business','healthcare','education','customer-service','content','code-completion','image-generation')
    $categories = @($defaultCategories + $CustomCategory | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique)
    $checked = (Get-Date).ToString('yyyy-MM-dd')
    $categoryMap = [ordered]@{}
    $failures = New-Object System.Collections.Generic.List[object]
    foreach ($category in $categories) {
        try {
            $count = Get-ModelCountForCategory -Category $category
            $categoryMap[$category] = [ordered]@{ status = if ($count -gt 0) { 'probed' } else { 'empty' }; last_checked = $checked; model_count_at_check = $count }
        } catch {
            $categoryMap[$category] = [ordered]@{ status = 'error'; last_checked = $checked; model_count_at_check = $null; error = $_.Exception.Message }
            $failures.Add([pscustomobject]@{ category=$category; error=$_.Exception.Message }) | Out-Null
        }
    }
    $result = [ordered]@{
        _about = [ordered]@{ purpose = 'Records whether /api/v1/models?category=<name> returns a non-empty model set.'; last_checked = $checked; generated_by = 'Discover-OpenRouterCategories.ps1'; caveat = 'OpenRouter does not publish classification criteria; treat categories as one recommendation signal only.' }
        categories = $categoryMap
    }
    if ($OutPath) { Write-StructuredOutput -Data $result -Path $OutPath; Write-Host "OpenRouter category cache written to $OutPath" }
    else {
        Write-Host '# OpenRouter Category Probe Report'
        Write-Host "Checked: $checked"
        foreach ($name in $categoryMap.Keys) { Write-Host "- ${name}: $($categoryMap[$name].status) ($($categoryMap[$name].model_count_at_check))" }
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
