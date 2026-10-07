# Title: discover.ps1 — OpenRouter model catalog discovery.
# Purpose: Fetch and normalize OpenRouter model metadata for registry flows.
# Inputs: Optional -Category plus optional -OutPath for JSON output.
# Outputs: Pretty JSON array on stdout or at -OutPath.
# Exit codes: 0 discovery succeeded; 1 HTTP or write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$Category = '',
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
$OpenRouterBaseUri = 'https://openrouter.ai/api/v1'

function Get-ObjectProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function ConvertTo-DecimalOrNull {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $text = [string]$Value
    $parsed = [decimal]0
    if ([decimal]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        return $parsed
    }
    return $null
}

function Infer-FamilyHint {
    param([string]$ModelId)
    if ([string]::IsNullOrWhiteSpace($ModelId)) { return 'other' }
    $normalized = $ModelId.Trim().ToLowerInvariant()
    $publisher = ($normalized -split '/')[0]
    $modelKey = ($normalized -split '/')[-1]

    switch -Wildcard ($publisher) {
        'anthropic'    { return 'anthropic' }
        'openai'       { return 'openai' }
        'google'       { return 'google' }
        'meta-llama'   { return 'meta-llama' }
        'mistralai'    { return 'mistral' }
        'deepseek'     { return 'deepseek' }
        'qwen'         { return 'qwen' }
        'x-ai'         { return 'x-ai' }
        'cohere'       { return 'cohere' }
        'perplexity'   { return 'perplexity' }
        'microsoft'    { return 'internal-microsoft' }
    }

    switch -Wildcard ($modelKey) {
        'claude*'      { return 'anthropic' }
        'gpt*'         { return 'openai' }
        'o1*'          { return 'openai' }
        'o3*'          { return 'openai' }
        'o4*'          { return 'openai' }
        'gemini*'      { return 'google' }
        'gemma*'       { return 'google' }
        'llama*'       { return 'meta-llama' }
        'mistral*'     { return 'mistral' }
        'mixtral*'     { return 'mistral' }
        'deepseek*'    { return 'deepseek' }
        'qwen*'        { return 'qwen' }
        'grok*'        { return 'x-ai' }
        'command*'     { return 'cohere' }
        'sonar*'       { return 'perplexity' }
        'mai-code-*'   { return 'internal-microsoft' }
        'mai-*'        { return 'internal-microsoft' }
        'goldeneye*'   { return 'internal-microsoft' }
        default        { return 'other' }
    }
}

function Get-SupportedParameterList {
    param($Model)
    $supported = Get-ObjectProperty -Object $Model -Name 'supported_parameters'
    if ($null -eq $supported) { return @() }
    if ($supported -is [string]) { return @($supported) }
    return @($supported | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Get-Notes {
    param($Model)
    $description = [string](Get-ObjectProperty -Object $Model -Name 'description')
    if ([string]::IsNullOrWhiteSpace($description)) { return '' }
    $singleLine = (($description -replace '\s+', ' ').Trim())
    if ($singleLine.Length -le 200) { return $singleLine }
    return $singleLine.Substring(0, 197) + '...'
}

function Convert-ModelRecord {
    param($Model)
    $modelId = [string](Get-ObjectProperty -Object $Model -Name 'id')
    $pricing = Get-ObjectProperty -Object $Model -Name 'pricing'
    $promptPerToken = ConvertTo-DecimalOrNull -Value (Get-ObjectProperty -Object $pricing -Name 'prompt')
    $completionPerToken = ConvertTo-DecimalOrNull -Value (Get-ObjectProperty -Object $pricing -Name 'completion')

    $promptPerMillion = $null
    $completionPerMillion = $null
    if ($null -ne $promptPerToken) { $promptPerMillion = [double]($promptPerToken * 1000000) }
    if ($null -ne $completionPerToken) { $completionPerMillion = [double]($completionPerToken * 1000000) }

    return [pscustomobject][ordered]@{
        model_id = $modelId
        family_hint = Infer-FamilyHint -ModelId $modelId
        context_window = Get-ObjectProperty -Object $Model -Name 'context_length'
        capabilities = @(Get-SupportedParameterList -Model $Model)
        pricing = [ordered]@{
            prompt_per_million = $promptPerMillion
            completion_per_million = $completionPerMillion
        }
        top_provider = Get-ObjectProperty -Object $Model -Name 'top_provider'
        notes = Get-Notes -Model $Model
    }
}

function Write-JsonOutput {
    param($Data, [string]$Path)
    $json = ConvertTo-Json -InputObject $Data -Depth 20
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Output $json
        return
    }
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-ErrorJson {
    param([string]$Message, [string]$Path)
    $payload = [ordered]@{
        status = 'error'
        adapter = 'openrouter'
        operation = 'discover'
        error = $Message
    }
    Write-JsonOutput -Data $payload -Path $Path
}

try {
    $uri = "$OpenRouterBaseUri/models"
    if (-not [string]::IsNullOrWhiteSpace($Category)) {
        $uri = "${uri}?category=$([System.Uri]::EscapeDataString($Category.Trim()))"
    }

    $response = Invoke-RestMethod -Uri $uri -Method Get
    $records = @()
    if ($response.PSObject.Properties['data']) { $records = @($response.data) }
    elseif ($response -is [System.Collections.IEnumerable] -and -not ($response -is [string])) { $records = @($response) }
    else { $records = @($response) }

    $normalized = @($records | ForEach-Object { Convert-ModelRecord -Model $_ })
    Write-JsonOutput -Data $normalized -Path $OutPath
    exit 0
} catch {
    Write-ErrorJson -Message $_.Exception.Message -Path $OutPath
    exit 1
}
