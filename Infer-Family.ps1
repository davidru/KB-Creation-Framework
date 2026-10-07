# Title: Infer-Family.ps1 — model family inference helper.
# Purpose: Infer a Model Registry family value from a provider model ID.
# Inputs: -ModelId plus optional -OutPath for structured output.
# Outputs: Family string on stdout, or JSON/YAML object at -OutPath.
# Exit codes: 0 success; 1 invalid input or output-write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ModelId,
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

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

function Infer-Family {
    param([string]$RawModelId)
    if ([string]::IsNullOrWhiteSpace($RawModelId)) { throw 'ModelId is required.' }
    $normalized = $RawModelId.Trim().ToLowerInvariant()
    $modelKey = ($normalized -split '/')[-1]
    switch -Wildcard ($modelKey) {
        'claude*'      { return 'anthropic' }
        'gpt*'         { return 'openai' }
        'o1*'          { return 'openai' }
        'gemini*'      { return 'google' }
        'llama*'       { return 'meta-llama' }
        'mistral*'     { return 'mistral' }
        'deepseek*'    { return 'deepseek' }
        'mai-code-*'   { return 'internal-microsoft' }
        'mai-*'        { return 'internal-microsoft' }
        'goldeneye*'   { return 'internal-microsoft' }
        default        { return $null }
    }
}

try {
    $family = Infer-Family -RawModelId $ModelId
    $prompted = $false
    if (-not $family) {
        $allowed = @('anthropic','openai','google','meta-llama','mistral','deepseek','internal-microsoft','other')
        $choice = $null
        try {
            $choice = Read-Host "Unrecognized model family for '$ModelId'. Enter one of [$($allowed -join ', ')] or press Enter for other"
            $prompted = $true
        } catch {
            Write-Warning "Could not prompt for unrecognized model '$ModelId'; using family 'other'."
        }
        if ($choice -and ($allowed -contains $choice.Trim().ToLowerInvariant())) { $family = $choice.Trim().ToLowerInvariant() } else { $family = 'other' }
    }

    if ($OutPath) {
        Write-StructuredOutput -Data ([ordered]@{ model_id = $ModelId; family = $family; prompted = $prompted }) -Path $OutPath
    } else {
        Write-Output $family
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
