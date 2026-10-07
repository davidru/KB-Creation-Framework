# Title: Recommend-Models.ps1 — cross-provider model recommender.
# Purpose: Rank provider-discovered models by role, cost, tier, recency, and domain signals.
# Inputs: Role, Provider, Domain, TopN, and optional structured -OutPath.
# Outputs: Human Markdown recommendation table or JSON/YAML structured output.
# Exit codes: 0 recommendations produced; 1 no usable provider/model data or write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][ValidateSet('lead','builder_a_b','critic_rubber_duck','fact_checker','auditor','memo_writer','ALL')][string]$Role = 'ALL',
    [Parameter(Mandatory=$false)][ValidateSet('copilot-cli','azure-foundry','openrouter','ollama','ALL')][string]$Provider = 'ALL',
    [Parameter(Mandatory=$false)][ValidateSet('legal','programming','finance','coding','general','ANY')][string]$Domain = 'ANY',
    [Parameter(Mandatory=$false)][ValidateRange(1,50)][int]$TopN = 5,
    [Parameter(Mandatory=$false)][string]$OutPath = '',
    [Parameter(Mandatory=$false)][switch]$GeneratePreset
)

$ErrorActionPreference = 'Stop'

function Test-Scalar { param($Value) return (($null -eq $Value) -or ($Value -is [string]) -or ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [decimal]) -or ($Value -is [bool])) }
function Format-YamlScalar { param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return [string]$Value }
    $text = [string]$Value
    if ($text -eq '') { return '""' }
    if ($text -match '[:#\[\]{},&*?]|^\s|\s$|\|') { return '"' + ($text -replace '"','\"') + '"' }
    return $text
}
function ConvertTo-SimpleYaml { param($Value, [int]$Indent = 0)
    $spaces = ' ' * $Indent; $lines = New-Object System.Collections.Generic.List[string]
    if (Test-Scalar $Value) { $lines.Add($spaces + (Format-YamlScalar $Value)) | Out-Null }
    elseif ($Value -is [System.Collections.IDictionary]) { foreach ($key in $Value.Keys) { $item=$Value[$key]; if (Test-Scalar $item) { $lines.Add(('{0}{1}: {2}' -f $spaces,$key,(Format-YamlScalar $item))) | Out-Null } else { $lines.Add(('{0}{1}:' -f $spaces,$key)) | Out-Null; foreach ($line in ConvertTo-SimpleYaml -Value $item -Indent ($Indent+2)) { $lines.Add($line) | Out-Null } } } }
    elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { foreach ($item in $Value) { if (Test-Scalar $item) { $lines.Add(('{0}- {1}' -f $spaces,(Format-YamlScalar $item))) | Out-Null } else { $lines.Add(('{0}-' -f $spaces)) | Out-Null; foreach ($line in ConvertTo-SimpleYaml -Value $item -Indent ($Indent+2)) { $lines.Add($line) | Out-Null } } } }
    else { $map=[ordered]@{}; foreach ($prop in $Value.PSObject.Properties) { $map[$prop.Name]=$prop.Value }; foreach ($line in ConvertTo-SimpleYaml -Value $map -Indent $Indent) { $lines.Add($line) | Out-Null } }
    return @($lines)
}
function Write-StructuredOutput { param($Data, [string]$Path)
    $parent=Split-Path -Parent $Path; if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ($Path -match '\.ya?ml$') { (ConvertTo-SimpleYaml -Value $Data) -join [Environment]::NewLine | Set-Content -LiteralPath $Path -Encoding UTF8 } else { $Data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8 }
}
function ConvertFrom-InlineList { param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $inner = $Text.Trim()
    if ($inner -match '^\[(.*)\]$') { $inner = $matches[1] }
    return @($inner -split ',' | ForEach-Object { ($_.Trim() -replace '^[''\"]|[''\"]$','') } | Where-Object { $_ })
}
function Get-RoleProfile { param([string]$Name)
    $path = Join-Path $PSScriptRoot 'audit-templates\role-profiles.yaml'
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing role profiles: $path" }
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $match = [regex]::Match($text, "(?ms)^  $([regex]::Escape($Name)):\s*(.*?)(?=^  [A-Za-z_][A-Za-z0-9_]*:|\z)")
    if (-not $match.Success) { throw "Role '$Name' not found in role-profiles.yaml" }
    $block = $match.Groups[1].Value
    $profile = [ordered]@{ role=$Name; min_context_length=0; capability_tier_allowlist=@('premium','advanced','mid','budget'); supports_tools=$false; preferred_families=@(); input_ratio=0.75; output_ratio=0.25; sensitivity_to_quality='medium'; sensitivity_to_cost='medium' }
    if ($block -match 'min_context_length:\s*([0-9]+)') { $profile.min_context_length = [int]$matches[1] }
    if ($block -match 'capability_tier_allowlist:\s*(\[[^\]]*\])') { $profile.capability_tier_allowlist = @(ConvertFrom-InlineList $matches[1]) }
    if ($block -match 'supports_tools:\s*(true|false)') { $profile.supports_tools = ([bool]::Parse($matches[1])) }
    if ($block -match 'preferred_families:\s*(\[[^\]]*\])') { $profile.preferred_families = @(ConvertFrom-InlineList $matches[1]) }
    if ($block -match 'input:\s*([0-9.]+)') { $profile.input_ratio = [double]$matches[1] }
    if ($block -match 'output:\s*([0-9.]+)') { $profile.output_ratio = [double]$matches[1] }
    if ($block -match 'sensitivity_to_quality:\s*(low|medium|high)') { $profile.sensitivity_to_quality = $matches[1] }
    if ($block -match 'sensitivity_to_cost:\s*(low|medium|high)') { $profile.sensitivity_to_cost = $matches[1] }
    return $profile
}
function Get-TierPatterns {
    $path = Join-Path $PSScriptRoot 'audit-templates\capability-tiers.yaml'
    $tiers = [ordered]@{ premium=@(); advanced=@(); mid=@(); budget=@() }
    if (-not (Test-Path -LiteralPath $path)) { return $tiers }
    $currentTier=''; $inPatterns=$false
    foreach ($raw in Get-Content -LiteralPath $path -Encoding UTF8) {
        $line = $raw.TrimEnd()
        if ($line -match '^  (premium|advanced|mid|budget):\s*$') { $currentTier=$matches[1]; $inPatterns=$false; continue }
        if ($currentTier -and $line -match '^    patterns:\s*$') { $inPatterns=$true; continue }
        if ($inPatterns -and $line -match '^      -\s*(.+?)\s*$') { $tiers[$currentTier] += (($matches[1].Trim()) -replace '^[''\"]|[''\"]$','') }
        elseif ($currentTier -and $line -match '^    [A-Za-z_].*:') { $inPatterns=$false }
    }
    return $tiers
}
function Get-DomainOverrides { param([string]$DomainName)
    $path = Join-Path $PSScriptRoot 'audit-templates\domain-capabilities.yaml'
    $result = [ordered]@{ premium=@(); advanced=@(); caution=@(); sources=@() }
    if ($DomainName -eq 'ANY' -or -not (Test-Path -LiteralPath $path)) { return $result }
    $wanted = if ($DomainName -eq 'programming') { 'coding' } else { $DomainName }
    $inDomain=$false; $currentOverride=''; $currentSource=$null
    foreach ($raw in Get-Content -LiteralPath $path -Encoding UTF8) {
        $line = $raw.TrimEnd()
        if ($line -match '^  ([A-Za-z0-9_-]+):\s*$') { $inDomain = ($matches[1] -eq $wanted); $currentOverride=''; continue }
        if (-not $inDomain) { continue }
        if ($line -match '^      - name:\s*(.+?)\s*$') { $result.sources += ($matches[1].Trim() -replace '^[''\"]|[''\"]$',''); continue }
        if ($line -match '^      (premium|advanced|caution)_[A-Za-z0-9_-]+:\s*$') { $currentOverride=$matches[1]; continue }
        if ($currentOverride -and $line -match '^        -\s*(.+?)\s*$') { $result[$currentOverride] += (($matches[1].Trim()) -replace '^[''\"]|[''\"]$','') }
    }
    return $result
}
function Get-ObjectValue { param($Object, [string[]]$Names)
    foreach ($name in $Names) { $p=$Object.PSObject.Properties[$name]; if ($p -and $null -ne $p.Value -and -not [string]::IsNullOrWhiteSpace([string]$p.Value)) { return $p.Value } }
    return $null
}
function ConvertTo-DoubleOrNull { param($Value) if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }; try { return [double]$Value } catch { return $null } }
function Get-ProviderList { if ($Provider -eq 'ALL') { return @('copilot-cli','azure-foundry','openrouter','ollama') } return @($Provider) }
function Get-RoleList { if ($Role -eq 'ALL') { return @('lead','builder_a_b','critic_rubber_duck','fact_checker','auditor','memo_writer') } return @($Role) }
function Invoke-ProviderDiscover { param([string]$ProviderName, [string]$Category = '')
    $discover = Join-Path $PSScriptRoot ("adapters\model-providers\$ProviderName\discover.ps1")
    if (-not (Test-Path -LiteralPath $discover)) { throw "discover.ps1 missing for provider '$ProviderName'" }
    $output = $null
    if ($ProviderName -eq 'openrouter' -and $Category) { $output = & $discover -Category $Category 2>&1 }
    elseif ($ProviderName -eq 'ollama') {
        $cacheDir = Join-Path $HOME '.kbframework\cache'
        if (-not (Test-Path -LiteralPath $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        $cache = Join-Path $cacheDir 'ollama-discover.json'
        $output = & $discover -OutPath $cache 2>&1
        if (Test-Path -LiteralPath $cache) { $output = Get-Content -LiteralPath $cache -Raw -Encoding UTF8 }
    } else { $output = & $discover 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "Provider '$ProviderName' discovery failed: $($output -join ' ')" }
    $text = ($output | Out-String).Trim()
    if (-not $text) { return @() }
    $jsonStart = $text.IndexOf('['); $objStart = $text.IndexOf('{')
    if ($jsonStart -lt 0 -or ($objStart -ge 0 -and $objStart -lt $jsonStart)) { $jsonStart = $objStart }
    if ($jsonStart -gt 0) { $text = $text.Substring($jsonStart) }
    $parsed = $text | ConvertFrom-Json
    if ($parsed.PSObject.Properties['status'] -and $parsed.status -eq 'error') { throw ($parsed.error | Out-String).Trim() }
    return @($parsed)
}
function Test-PatternMatch { param([string]$ModelId, [string]$Pattern)
    if ([string]::IsNullOrWhiteSpace($Pattern)) { return $false }
    $id = $ModelId.ToLowerInvariant(); $key = (($id -split '/')[-1])
    $p = $Pattern.ToLowerInvariant()
    return ($id -like $p -or $key -like $p)
}
function Test-AnyPattern { param([string]$ModelId, [string[]]$Patterns)
    foreach ($p in @($Patterns)) { if (Test-PatternMatch -ModelId $ModelId -Pattern $p) { return $true } }
    return $false
}
function Get-CapabilityTier { param([string]$ModelId, $TierPatterns)
    $priority = @{ premium=4; advanced=3; mid=2; budget=1 }
    $best = [ordered]@{ tier='unknown'; specificity=0; priority=0 }
    foreach ($tier in @('premium','advanced','mid','budget')) {
        foreach ($pattern in @($TierPatterns[$tier])) {
            if (Test-PatternMatch -ModelId $ModelId -Pattern $pattern) {
                $specificity = ($pattern -replace '[\*\?]','').Length
                if ($specificity -gt $best.specificity -or ($specificity -eq $best.specificity -and $priority[$tier] -gt $best.priority)) { $best.tier=$tier; $best.specificity=$specificity; $best.priority=$priority[$tier] }
            }
        }
    }
    return $best.tier
}
function Get-RecencyBonus { param([string]$ModelId)
    $id = $ModelId.ToLowerInvariant()
    if ($id -match 'gpt-5|claude-opus-4|claude-sonnet-4|gemini-3|gemini-2\.5|o[134]|deepseek-chat-v3|gpt-oss') { return 10 }
    if ($id -match 'gpt-4o|claude-3\.5|gemini-1\.5|llama-3\.3') { return 6 }
    return 2
}
function Get-SensitivityWeight { param([string]$Sensitivity, [string]$Kind)
    if ($Kind -eq 'quality') { switch ($Sensitivity) { 'high' { return 0.60 } 'medium' { return 0.45 } default { return 0.35 } } }
    switch ($Sensitivity) { 'high' { return 0.35 } 'medium' { return 0.25 } default { return 0.10 } }
}
function Get-TierScore { param([string]$Tier) switch ($Tier) { 'premium' {100} 'advanced' {78} 'mid' {55} 'budget' {38} default {45} } }
function Normalize-Model { param($Model, [string]$ProviderName)
    $modelId = [string](Get-ObjectValue -Object $Model -Names @('model_id','id','name'))
    if ([string]::IsNullOrWhiteSpace($modelId)) { return $null }
    $pricing = $Model.PSObject.Properties['pricing'].Value
    $prompt = if ($pricing) { ConvertTo-DoubleOrNull (Get-ObjectValue -Object $pricing -Names @('prompt_per_million','prompt')) } else { $null }
    $completion = if ($pricing) { ConvertTo-DoubleOrNull (Get-ObjectValue -Object $pricing -Names @('completion_per_million','completion')) } else { $null }
    $context = ConvertTo-DoubleOrNull (Get-ObjectValue -Object $Model -Names @('context_window','context_window_estimate','context_length'))
    $caps = @(); $capProp=$Model.PSObject.Properties['capabilities']; if ($capProp) { $caps = @($capProp.Value | ForEach-Object { [string]$_ }) }
    [pscustomobject][ordered]@{ provider=$ProviderName; model_id=$modelId; family_hint=[string](Get-ObjectValue -Object $Model -Names @('family_hint','family')); context_window=$context; capabilities=$caps; prompt_per_million=$prompt; completion_per_million=$completion; notes=[string](Get-ObjectValue -Object $Model -Names @('notes','description')) }
}

try {
    $providers = @(Get-ProviderList)
    $roles = @(Get-RoleList)
    $tierPatterns = Get-TierPatterns
    $domainOverrides = Get-DomainOverrides -DomainName $Domain
    $warnings = New-Object System.Collections.Generic.List[string]
    $allModels = New-Object System.Collections.Generic.List[object]
    $categoryModels = @{}
    $categoryName = switch ($Domain) { 'coding' { 'programming' } 'programming' { 'programming' } 'ANY' { '' } default { $Domain } }

    foreach ($providerName in $providers) {
        try {
            $models = @(Invoke-ProviderDiscover -ProviderName $providerName | ForEach-Object { Normalize-Model -Model $_ -ProviderName $providerName } | Where-Object { $null -ne $_ })
            foreach ($m in $models) { $allModels.Add($m) | Out-Null }
            if ($providerName -eq 'openrouter' -and $categoryName) {
                try {
                    $categorySet = @(Invoke-ProviderDiscover -ProviderName $providerName -Category $categoryName | ForEach-Object { [string](Get-ObjectValue -Object $_ -Names @('model_id','id','name')) } | Where-Object { $_ } | Select-Object -Unique)
                    foreach ($id in $categorySet) { $categoryModels[$id] = $true }
                } catch { $warnings.Add("OpenRouter category '$categoryName' probe failed: $($_.Exception.Message)") | Out-Null }
            }
        } catch { $warnings.Add($_.Exception.Message) | Out-Null }
    }
    if ($allModels.Count -eq 0) { throw "No provider models discovered. Warnings: $($warnings -join '; ')" }

    $priced = @($allModels | Where-Object { $null -ne $_.prompt_per_million -and $null -ne $_.completion_per_million } | ForEach-Object { $_.prompt_per_million + $_.completion_per_million })
    $minPrice = if ($priced.Count -gt 0) { ($priced | Measure-Object -Minimum).Minimum } else { 0 }
    $maxPrice = if ($priced.Count -gt 0) { ($priced | Measure-Object -Maximum).Maximum } else { 1 }

    $roleResults = [ordered]@{}
    foreach ($roleName in $roles) {
        $profile = Get-RoleProfile -Name $roleName
        $ranked = foreach ($model in $allModels) {
            $tier = Get-CapabilityTier -ModelId $model.model_id -TierPatterns $tierPatterns
            if ($profile.capability_tier_allowlist -notcontains $tier) { continue }
            if ($profile.min_context_length -gt 0 -and $model.context_window -and $model.context_window -lt $profile.min_context_length) { continue }
            $supportsTools = (@($model.capabilities) -contains 'tools') -or ($model.provider -eq 'copilot-cli')
            if ($profile.supports_tools -and -not $supportsTools) { continue }
            $combinedPrice = if ($null -ne $model.prompt_per_million -and $null -ne $model.completion_per_million) { ($profile.input_ratio * $model.prompt_per_million) + ($profile.output_ratio * $model.completion_per_million) } else { $null }
            $costScore = 55
            if ($model.provider -eq 'ollama') { $costScore = 100 }
            elseif ($null -ne $combinedPrice -and $maxPrice -gt $minPrice) { $costScore = [math]::Max(0, [math]::Min(100, 100 - ((($combinedPrice - $minPrice) / ($maxPrice - $minPrice)) * 100))) }
            $benchmarkSignal = 'neutral'; $benchmarkBonus = 0
            if (Test-AnyPattern -ModelId $model.model_id -Patterns $domainOverrides.premium) { $benchmarkSignal='premium'; $benchmarkBonus=15 }
            elseif (Test-AnyPattern -ModelId $model.model_id -Patterns $domainOverrides.advanced) { $benchmarkSignal='advanced'; $benchmarkBonus=8 }
            elseif (Test-AnyPattern -ModelId $model.model_id -Patterns $domainOverrides.caution) { $benchmarkSignal='caution'; $benchmarkBonus=-20 }
            $openRouterSignal = if ($categoryModels.ContainsKey($model.model_id)) { 'category-match' } elseif ($model.provider -eq 'openrouter' -and $categoryName) { 'not-in-category' } else { 'not-applicable' }
            $openRouterBonus = if ($openRouterSignal -eq 'category-match') { 10 } else { 0 }
            $familyBonus = if ($profile.preferred_families -contains $model.family_hint) { 5 } else { 0 }
            $score = ((Get-TierScore $tier) * (Get-SensitivityWeight -Sensitivity $profile.sensitivity_to_quality -Kind 'quality')) + ($costScore * (Get-SensitivityWeight -Sensitivity $profile.sensitivity_to_cost -Kind 'cost')) + (Get-RecencyBonus $model.model_id) + $benchmarkBonus + $openRouterBonus + $familyBonus
            [pscustomobject][ordered]@{ role=$roleName; provider=$model.provider; model_id=$model.model_id; family=$model.family_hint; capability_tier=$tier; score=[math]::Round($score,2); context_window=$model.context_window; supports_tools=$supportsTools; prompt_per_million=$model.prompt_per_million; completion_per_million=$model.completion_per_million; openrouter_category_signal=$openRouterSignal; benchmark_domain_signal=$benchmarkSignal; notes=$model.notes }
        }
        $roleResults[$roleName] = @($ranked | Sort-Object -Property score -Descending | Select-Object -First $TopN)
    }

    $preset = $null
    if ($GeneratePreset) {
        $preset = [ordered]@{}
        foreach ($roleName in $roles) { if (@($roleResults[$roleName]).Count -gt 0) { $preset[$roleName] = "$($roleResults[$roleName][0].provider):$($roleResults[$roleName][0].model_id)" } }
    }
    $result = [ordered]@{ generated_at=(Get-Date).ToString('o'); role=$Role; provider=$Provider; domain=$Domain; top_n=$TopN; warnings=$warnings.ToArray(); recommendations=$roleResults; generated_preset=$preset }
    if ($OutPath) { Write-StructuredOutput -Data $result -Path $OutPath; Write-Host "Model recommendations written to $OutPath" }
    else {
        Write-Host '# Model Recommendations'
        Write-Host "Provider: $Provider | Role: $Role | Domain: $Domain | TopN: $TopN"
        foreach ($warning in $warnings) { Write-Host "- WARN: $warning" }
        foreach ($roleName in $roleResults.Keys) {
            Write-Host "`n## $roleName"
            Write-Host '| Rank | Provider | Model | Tier | Score | Cost input/output per 1M | OpenRouter category | Benchmark signal |'
            Write-Host '|---:|---|---|---|---:|---|---|---|'
            $i=1
            foreach ($r in @($roleResults[$roleName])) { Write-Host ("| {0} | {1} | {2} | {3} | {4} | {5}/{6} | {7} | {8} |" -f $i,$r.provider,$r.model_id,$r.capability_tier,$r.score,$r.prompt_per_million,$r.completion_per_million,$r.openrouter_category_signal,$r.benchmark_domain_signal); $i++ }
            if ($i -eq 1) { Write-Host '_No models met the hard requirements._' }
        }
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
