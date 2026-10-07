# Title: Estimate-BuildCost.ps1 — KB build token and dollar estimator.
# Purpose: Estimate per-phase/per-model cost from scoping report, state, and pricing metadata.
# Inputs: -KBRoot plus optional registry path and structured -OutPath.
# Outputs: Markdown cost report or JSON/YAML report at -OutPath.
# Exit codes: 0 estimate generated; 1 required inputs missing or malformed.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$KBRoot,
    [Parameter(Mandatory=$false)][string]$RegistryPath = (Join-Path $PSScriptRoot 'model-registry.yaml'),
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
function Test-Scalar { param($Value) return (($null -eq $Value) -or ($Value -is [string]) -or ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [bool])) }
function Format-YamlScalar { param($Value) if($null -eq $Value){'null'} elseif($Value -is [bool]){$Value.ToString().ToLowerInvariant()} elseif($Value -is [int] -or $Value -is [long] -or $Value -is [double]){[string]$Value} else { $t=[string]$Value; if($t -match '[:#\[\]{},&*?]|^\s|\s$|\|'){'"'+($t -replace '"','\"')+'"'}else{$t} } }
function ConvertTo-SimpleYaml { param($Value,[int]$Indent=0) $s=' '*$Indent; $l=New-Object System.Collections.Generic.List[string]; if(Test-Scalar $Value){$l.Add($s+(Format-YamlScalar $Value))|Out-Null}elseif($Value -is [System.Collections.IDictionary]){foreach($k in $Value.Keys){$i=$Value[$k]; if(Test-Scalar $i){$l.Add(('{0}{1}: {2}' -f $s,$k,(Format-YamlScalar $i)))|Out-Null}else{$l.Add(('{0}{1}:' -f $s,$k))|Out-Null; foreach($line in ConvertTo-SimpleYaml $i ($Indent+2)){$l.Add($line)|Out-Null}}}}elseif($Value -is [System.Collections.IEnumerable] -and -not($Value -is [string])){foreach($i in $Value){if(Test-Scalar $i){$l.Add(('{0}- {1}' -f $s,(Format-YamlScalar $i)))|Out-Null}else{$l.Add(('{0}-' -f $s))|Out-Null; foreach($line in ConvertTo-SimpleYaml $i ($Indent+2)){$l.Add($line)|Out-Null}}}}else{$m=[ordered]@{};foreach($p in $Value.PSObject.Properties){$m[$p.Name]=$p.Value};foreach($line in ConvertTo-SimpleYaml $m $Indent){$l.Add($line)|Out-Null}};return @($l)}
function Write-StructuredOutput { param($Data,[string]$Path) $parent=Split-Path -Parent $Path; if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}; if($Path -match '\.ya?ml$'){(ConvertTo-SimpleYaml $Data)-join[Environment]::NewLine|Set-Content -LiteralPath $Path -Encoding UTF8}else{$Data|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $Path -Encoding UTF8} }
function Resolve-RegistryPath { param([string]$Path) if(Test-Path -LiteralPath $Path){return (Resolve-Path -LiteralPath $Path).Path}; $ex=Join-Path $PSScriptRoot 'model-registry.example.yaml'; if((Split-Path -Leaf $Path)-eq 'model-registry.yaml' -and (Test-Path -LiteralPath $ex)){return (Resolve-Path -LiteralPath $ex).Path}; throw "RegistryPath not found: $Path" }
function Read-Text { param([string]$Path) if(Test-Path -LiteralPath $Path){return Get-Content -LiteralPath $Path -Raw -Encoding UTF8}; return '' }
function Get-IntMatch { param([string]$Text,[string[]]$Patterns,[int]$Default) foreach($p in $Patterns){ if($Text -match $p){return [int]$matches[1]} }; return $Default }
function Get-ModelAssignment { param([string]$Text)
    $roles=@('lead','builder_a','builder_b','critic_pool','factcheck_pool_5a_5b_5c','factcheck_pool_5d_5e','factcheck_6b','auditor_7','memo_factcheck_8')
    $assignment=[ordered]@{}
    foreach($role in $roles){ if($Text -match "(?im)^\s*$([regex]::Escape($role))\s*:\s*(.+?)\s*$"){ $raw=$matches[1].Trim(); if($raw -match '^\[(.*)\]$'){$assignment[$role]=@($matches[1] -split ',' | ForEach-Object { ($_.Trim() -replace '^[''\"]|[''\"]$','') } | Where-Object {$_})}else{$assignment[$role]=@(($raw -replace '^[''\"]|[''\"]$',''))} } }
    return $assignment
}
function Resolve-Handle { param([string]$Handle,[string]$Reg)
    $resolver=Join-Path $PSScriptRoot 'Resolve-Model.ps1'
    $out=& $resolver -Handle $Handle -RegistryPath $Reg
    if($LASTEXITCODE -ne 0){ throw "Resolve failed for ${Handle}: $($out -join ' ')" }
    $objects=@($out | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] -and $_ -isnot [System.Management.Automation.ErrorRecord] })
    if($objects.Count -eq 0){ throw "Resolve-Model.ps1 returned no object for handle ${Handle}." }
    return $objects[0]
}
function Invoke-Discover { param([string]$Provider)
    $discover=Join-Path $PSScriptRoot "adapters\model-providers\$Provider\discover.ps1"
    if(-not(Test-Path -LiteralPath $discover)){return @()}
    if($Provider -eq 'ollama'){ $cacheDir=Join-Path $HOME '.kbframework\cache'; if(-not(Test-Path -LiteralPath $cacheDir)){New-Item -ItemType Directory -Path $cacheDir -Force|Out-Null}; $cache=Join-Path $cacheDir 'ollama-pricing.json'; & $discover -OutPath $cache | Out-Null; if(Test-Path -LiteralPath $cache){return @(Get-Content -LiteralPath $cache -Raw -Encoding UTF8 | ConvertFrom-Json)}; return @() }
    $out=& $discover 2>$null
    if($LASTEXITCODE -ne 0 -or -not $out){return @()}
    $txt=($out|Out-String).Trim(); $start=$txt.IndexOf('['); if($start -gt 0){$txt=$txt.Substring($start)}; return @($txt|ConvertFrom-Json)
}
function Get-Price { param([string]$Provider,[string]$ModelId,$Catalog)
    if($Provider -eq 'copilot-cli'){return [ordered]@{ basis='N/A (usage-based)'; prompt_per_million=$null; completion_per_million=$null }}
    if($Provider -eq 'ollama'){return [ordered]@{ basis='$0 (local)'; prompt_per_million=0; completion_per_million=0 }}
    $entry=@($Catalog[$Provider] | Where-Object { $_.model_id -eq $ModelId -or $_.id -eq $ModelId } | Select-Object -First 1)
    if($entry.Count -gt 0 -and $entry[0].pricing){return [ordered]@{ basis='provider pricing'; prompt_per_million=$entry[0].pricing.prompt_per_million; completion_per_million=$entry[0].pricing.completion_per_million }}
    return [ordered]@{ basis='unknown'; prompt_per_million=$null; completion_per_million=$null }
}

try {
    if(-not(Test-Path -LiteralPath $KBRoot -PathType Container)){throw "KBRoot not found: $KBRoot"}
    $KBRoot=(Resolve-Path -LiteralPath $KBRoot).Path
    $scoping=Read-Text (Join-Path $KBRoot 'sources\scoping_report.md')
    $statePath=Join-Path $KBRoot 'sources\pipeline_state.md'
    $state=Read-Text $statePath
    if(-not $state){throw "pipeline_state.md missing or empty: $statePath"}
    $topicCount=Get-IntMatch $scoping @('(?i)topic\s*count\D+(\d+)','(?i)(\d+)\s+topics?') 5
    $tierA=Get-IntMatch $scoping @('(?i)Tier[-\s]?A\D+(\d+)') ([math]::Ceiling($topicCount*0.35))
    $tierB=Get-IntMatch $scoping @('(?i)Tier[-\s]?B\D+(\d+)') ([math]::Max(0,$topicCount-$tierA))
    $densityMultiplier=1 + ([math]::Min(2.0, (($tierA*0.20)+($tierB*0.08))))
    $assignment=Get-ModelAssignment $state
    if($assignment.Keys.Count -eq 0){throw 'No model_assignment handles found in pipeline_state.md.'}
    $reg=Resolve-RegistryPath $RegistryPath
    $catalog=@{}; foreach($provider in @('openrouter','azure-foundry','ollama','copilot-cli')){try{$catalog[$provider]=@(Invoke-Discover $provider)}catch{$catalog[$provider]=@()}}
    $phaseMap=@(
        [ordered]@{ phase='Phase 1-2 lead orchestration'; role='lead'; input=18000; output=6000 },
        [ordered]@{ phase='Phase 3 builder A'; role='builder_a'; input=42000; output=14000 },
        [ordered]@{ phase='Phase 3 builder B'; role='builder_b'; input=42000; output=14000 },
        [ordered]@{ phase='Phase 4 critic'; role='critic_pool'; input=26000; output=7000 },
        [ordered]@{ phase='Phase 5 fact-check'; role='factcheck_pool_5a_5b_5c'; input=32000; output=5000 },
        [ordered]@{ phase='Phase 5d-5e audit'; role='factcheck_pool_5d_5e'; input=26000; output=5000 },
        [ordered]@{ phase='Phase 6b stress'; role='factcheck_6b'; input=24000; output=5000 },
        [ordered]@{ phase='Phase 7 auditor'; role='auditor_7'; input=28000; output=6000 },
        [ordered]@{ phase='Phase 8 memo fact-check'; role='memo_factcheck_8'; input=22000; output=6000 }
    )
    $rows=New-Object System.Collections.Generic.List[object]; $total=0.0; $unknown=New-Object System.Collections.Generic.List[string]
    foreach($phase in $phaseMap){ if(-not $assignment.Contains($phase.role)){continue}; foreach($handle in @($assignment[$phase.role])){ $resolved=Resolve-Handle $handle $reg; $price=Get-Price $resolved.provider $resolved.model_id $catalog; $inTokens=[math]::Round($phase.input*$topicCount*$densityMultiplier); $outTokens=[math]::Round($phase.output*$topicCount*$densityMultiplier); $cost=$null; if($null -ne $price.prompt_per_million -and $null -ne $price.completion_per_million){$cost= (($inTokens/1000000)*[double]$price.prompt_per_million)+(($outTokens/1000000)*[double]$price.completion_per_million); $total += $cost}else{$unknown.Add("$($phase.phase): $handle ($($price.basis))")|Out-Null}; $rows.Add([pscustomobject][ordered]@{ phase=$phase.phase; role=$phase.role; handle=$handle; provider=$resolved.provider; model_id=$resolved.model_id; input_tokens=$inTokens; output_tokens=$outTokens; pricing_basis=$price.basis; estimated_cost_usd=if($null -eq $cost){$null}else{[math]::Round($cost,4)} })|Out-Null } }
    $result=[ordered]@{ generated_at=(Get-Date).ToString('o'); kb_root=$KBRoot; topic_count=$topicCount; tier_a=$tierA; tier_b=$tierB; density_multiplier=[math]::Round($densityMultiplier,2); per_phase=$rows.ToArray(); known_total_usd=[math]::Round($total,4); confidence_band_usd=[ordered]@{ low=[math]::Round($total*0.5,4); high=[math]::Round($total*1.5,4) }; unknown_cost_items=$unknown.ToArray() }
    if($OutPath){Write-StructuredOutput $result $OutPath; Write-Host "Build cost estimate written to $OutPath"}else{Write-Host '# KB Build Cost Estimate'; Write-Host "KBRoot: $KBRoot"; Write-Host "Topics: $topicCount (Tier-A=$tierA Tier-B=$tierB)"; Write-Host '| Phase | Handle | Provider/model | Input | Output | Cost |'; Write-Host '|---|---|---|---:|---:|---:|'; foreach($r in $rows){Write-Host "| $($r.phase) | $($r.handle) | $($r.provider)/$($r.model_id) | $($r.input_tokens) | $($r.output_tokens) | $($r.estimated_cost_usd) |"}; Write-Host "`nKnown-price total: `$$([math]::Round($total,2)) (confidence band `$$([math]::Round($total*0.5,2)) - `$$([math]::Round($total*1.5,2)))"; foreach($u in $unknown){Write-Host "- Cost not priced: $u"}}
    exit 0
} catch { Write-Error $_.Exception.Message; exit 1 }
