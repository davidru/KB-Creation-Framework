# Title: discover.ps1 — Azure Foundry deployment discovery.
# Purpose: List resource-configured deployments for registry generation.
# Inputs: Optional -OutPath; env vars select Azure CLI or REST path.
# Outputs: Pretty JSON array of normalized model/deployment metadata.
# Exit codes: 0 success; 1 discovery or configuration error.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'

function Get-OptionalEnv {
    param([Parameter(Mandatory=$true)][string]$Name)

    return [Environment]::GetEnvironmentVariable($Name)
}

function Get-RequiredEnv {
    param([Parameter(Mandatory=$true)][string]$Name)

    $value = Get-OptionalEnv -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable is not set: env:$Name"
    }
    return $value
}

function Get-ApiVersion {
    $value = Get-OptionalEnv -Name 'AZURE_FOUNDRY_API_VERSION'
    if ([string]::IsNullOrWhiteSpace($value)) { return '2024-10-21' }
    return $value
}

function Get-ObjectValue {
    param(
        [Parameter(Mandatory=$true)]$Object,
        [Parameter(Mandatory=$true)][string[]]$Path
    )

    $current = $Object
    foreach ($name in $Path) {
        if ($null -eq $current) { return $null }
        if ($current -is [System.Collections.IDictionary] -and $current.Contains($name)) {
            $current = $current[$name]
            continue
        }
        $property = $current.PSObject.Properties[$name]
        if ($null -eq $property) { return $null }
        $current = $property.Value
    }
    return $current
}

function Get-FirstObjectValue {
    param(
        [Parameter(Mandatory=$true)]$Object,
        [Parameter(Mandatory=$true)][object[]]$Paths
    )

    foreach ($path in $Paths) {
        $value = Get-ObjectValue -Object $Object -Path ([string[]]$path)
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return $value }
    }
    return $null
}

function Get-FamilyHint {
    param([AllowNull()][string]$ModelName)

    if ([string]::IsNullOrWhiteSpace($ModelName)) { return 'unknown' }
    $name = $ModelName.ToLowerInvariant()
    if ($name -match 'deepseek') { return 'deepseek' }
    if ($name -match 'claude') { return 'anthropic' }
    if ($name -match 'gemini') { return 'google' }
    if ($name -match 'llama') { return 'meta-llama' }
    if ($name -match 'mistral|mixtral') { return 'mistral' }
    if ($name -match 'mai|phi') { return 'internal-microsoft' }
    if ($name -match 'gpt|\bo[1-9]\b|\bo[1-9]-|\bo[1-9]') { return 'openai' }
    return 'unknown'
}

function Get-InferredContextWindow {
    param([AllowNull()][string]$ModelName)

    if ([string]::IsNullOrWhiteSpace($ModelName)) { return $null }
    $name = $ModelName.ToLowerInvariant()
    if ($name -match 'gpt-4\.1|gpt-4o|gpt-4-turbo|\bo1\b|\bo3\b|\bo4\b') { return 128000 }
    if ($name -match 'gpt-35|gpt-3\.5') { return 16385 }
    if ($name -match 'claude-3|claude-sonnet|claude-opus|claude-haiku') { return 200000 }
    if ($name -match 'gemini-1\.5|gemini-2') { return 1000000 }
    if ($name -match 'deepseek-r1|deepseek-chat') { return 64000 }
    if ($name -match 'mistral-large|mistral-small|mixtral') { return 128000 }
    if ($name -match 'embedding') { return 8191 }
    return $null
}

function Get-Capabilities {
    param([AllowNull()][string]$ModelName)

    $capabilities = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($ModelName)) {
        $capabilities.Add('text') | Out-Null
        return @($capabilities)
    }

    $name = $ModelName.ToLowerInvariant()
    if ($name -match 'embedding') {
        $capabilities.Add('embeddings') | Out-Null
        return @($capabilities)
    }
    if ($name -match 'dall-e|image') {
        $capabilities.Add('image') | Out-Null
        return @($capabilities)
    }

    $capabilities.Add('text') | Out-Null
    if ($name -match 'gpt|claude|gemini|mistral|mixtral|llama|mai|phi') { $capabilities.Add('tools') | Out-Null }
    if ($name -match 'gpt-4o|vision|omni') { $capabilities.Add('vision') | Out-Null }
    if ($name -match '\bo1\b|\bo3\b|\bo4\b|reason|deepseek-r1|mai') { $capabilities.Add('reasoning') | Out-Null }
    return @($capabilities | Select-Object -Unique)
}

function New-DiscoveryItem {
    param(
        [Parameter(Mandatory=$true)][string]$ModelId,
        [AllowNull()][string]$ModelName,
        [AllowNull()]$ContextWindow,
        [Parameter(Mandatory=$true)][string]$Notes
    )

    if ($null -eq $ContextWindow) { $ContextWindow = Get-InferredContextWindow -ModelName $ModelName }
    [ordered]@{
        model_id = $ModelId
        family_hint = Get-FamilyHint -ModelName $ModelName
        context_window = $ContextWindow
        capabilities = @(Get-Capabilities -ModelName $ModelName)
        pricing = $null
        notes = $Notes
    }
}

function ConvertFrom-AzDeployment {
    param([Parameter(Mandatory=$true)]$Deployment)

    $deploymentName = [string](Get-FirstObjectValue -Object $Deployment -Paths @(@('name'), @('deploymentName')))
    $modelName = [string](Get-FirstObjectValue -Object $Deployment -Paths @(@('properties','model','name'), @('model','name'), @('properties','modelName'), @('modelName')))
    $modelVersion = [string](Get-FirstObjectValue -Object $Deployment -Paths @(@('properties','model','version'), @('model','version'), @('properties','modelVersion')))
    $contextWindow = Get-FirstObjectValue -Object $Deployment -Paths @(@('properties','model','contextWindow'), @('properties','capabilities','contextWindow'), @('context_window'))
    $skuName = [string](Get-FirstObjectValue -Object $Deployment -Paths @(@('sku','name'), @('properties','sku','name')))

    $noteParts = New-Object System.Collections.Generic.List[string]
    $noteParts.Add('Discovered via az CLI from deployments configured in env:AZURE_RESOURCE_NAME / env:AZURE_RESOURCE_GROUP.') | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($modelName)) { $noteParts.Add("Underlying model: $modelName.") | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($modelVersion)) { $noteParts.Add("Version: $modelVersion.") | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($skuName)) { $noteParts.Add("SKU: $skuName.") | Out-Null }

    return New-DiscoveryItem -ModelId $deploymentName -ModelName $modelName -ContextWindow $contextWindow -Notes (($noteParts -join ' ').Trim())
}

function ConvertFrom-RestModel {
    param([Parameter(Mandatory=$true)]$Model)

    $modelId = [string](Get-FirstObjectValue -Object $Model -Paths @(@('id'), @('name'), @('model'), @('model_id')))
    $modelName = [string](Get-FirstObjectValue -Object $Model -Paths @(@('model'), @('name'), @('id'), @('model_id')))
    $contextWindow = Get-FirstObjectValue -Object $Model -Paths @(@('context_window'), @('contextWindow'), @('capabilities','contextWindow'))
    $notes = 'Discovered via REST fallback /openai/models for this resource; Azure CLI usually provides richer deployment metadata.'
    return New-DiscoveryItem -ModelId $modelId -ModelName $modelName -ContextWindow $contextWindow -Notes $notes
}

function Get-AzDeployments {
    $resourceName = Get-OptionalEnv -Name 'AZURE_RESOURCE_NAME'
    $resourceGroup = Get-OptionalEnv -Name 'AZURE_RESOURCE_GROUP'
    if ([string]::IsNullOrWhiteSpace($resourceName) -or [string]::IsNullOrWhiteSpace($resourceGroup)) { return $null }
    if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) { return $null }

    $json = & az cognitiveservices account deployment list --name $resourceName --resource-group $resourceGroup --output json
    if ($LASTEXITCODE -ne 0) { throw "az cognitiveservices account deployment list failed with exit code $LASTEXITCODE" }
    if ([string]::IsNullOrWhiteSpace(($json -join [Environment]::NewLine))) { return @() }
    return @((($json -join [Environment]::NewLine) | ConvertFrom-Json) | ForEach-Object { ConvertFrom-AzDeployment -Deployment $_ })
}

function Get-RestModels {
    $endpoint = (Get-RequiredEnv -Name 'AZURE_FOUNDRY_ENDPOINT').TrimEnd('/')
    $apiKey = Get-RequiredEnv -Name 'AZURE_FOUNDRY_API_KEY'
    $apiVersion = Get-ApiVersion
    $uri = "$endpoint/openai/models?api-version=$apiVersion"
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ 'api-key' = $apiKey }

    $items = @()
    if ($response.data) { $items = @($response.data) }
    elseif ($response.value) { $items = @($response.value) }
    elseif ($response -is [System.Collections.IEnumerable] -and $response -isnot [string]) { $items = @($response) }
    else { $items = @($response) }

    return @($items | Where-Object { $null -ne $_ } | ForEach-Object { ConvertFrom-RestModel -Model $_ })
}

function Write-JsonOutput {
    param(
        [Parameter(Mandatory=$true)]$Data,
        [Parameter(Mandatory=$false)][string]$Path = ''
    )

    $json = ConvertTo-Json -InputObject @($Data) -Depth 20
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Output $json
        return
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json | Set-Content -LiteralPath $Path -Encoding utf8
}

try {
    $results = $null
    try { $results = Get-AzDeployments } catch { $results = $null }
    if ($null -eq $results) { $results = Get-RestModels }

    Write-JsonOutput -Data @($results) -Path $OutPath
    exit 0
} catch {
    $errorResult = [ordered]@{
        status = 'error'
        adapter = 'azure-foundry'
        error = $_.Exception.Message
    }
    [Console]::Error.WriteLine(($errorResult | ConvertTo-Json -Depth 10))
    exit 1
}
