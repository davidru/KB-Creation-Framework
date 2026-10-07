# Title: Initialize-Framework.ps1 — first-time KB Framework setup wizard.
# Purpose: Configure host/provider preferences, discover models, recommend presets, and validate setup.
# Inputs: Optional -NonInteractive, -SkipSmokeBuild, and structured -OutPath.
# Outputs: Markdown setup transcript or JSON/YAML summary at -OutPath.
# Exit codes: 0 setup completed; 1 validation or write failure.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][switch]$NonInteractive,
    [Parameter(Mandatory=$false)][switch]$SkipSmokeBuild,
    [Parameter(Mandatory=$false)][string]$OutPath = '',
    [Parameter(Mandatory=$false)][switch]$Help
)

if ($Help) {
    Write-Host @"
Initialize-Framework.ps1 — first-time KB Framework setup wizard

Usage:
    Initialize-Framework.ps1 [-NonInteractive] [-SkipSmokeBuild] [-OutPath <path>]
    Initialize-Framework.ps1 -Help

Parameters:
    -NonInteractive  Run with all defaults; suitable for CI or scripted setup.
                     No prompts; accepts all default answers.
    -SkipSmokeBuild  Skip the optional 5-topic smoke build at the end.
    -OutPath         Optional. If provided, the setup summary is written
                     as structured JSON to this path. Otherwise emitted
                     to stdout.
    -Help            Print this help and exit 0.

Behavior:
    Multi-stage interactive wizard:
      1. Host selection (copilot-cli or opencode) — writes preference to
         ~/.kbframework/host_preference.yaml.
      2. Provider configuration (copilot-cli, azure-foundry, openrouter,
         ollama) — warns on missing env vars.
      3. Model discovery — invokes each configured provider's discover.ps1
         and caches results under ~/.kbframework/discovery/.
      4. Optional starter recommendations via Recommend-Models.ps1.
      5. Validation via Test-Setup.ps1.
      6. Optional 5-topic smoke build (manual dispatch hint).

Exit codes:
    0  Setup completed (warnings recorded but not blocking)
    1  Validation or write failure
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
function Ask { param([string]$Prompt,[string]$Default='') if($NonInteractive){return $Default}; try{ $v=Read-Host "$Prompt$(if($Default){" [$Default]"})"; if([string]::IsNullOrWhiteSpace($v)){return $Default}; return $v }catch{return $Default} }
function Write-Json { param($Data,[string]$Path) $parent=Split-Path -Parent $Path;if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$Data|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8 }
try { $summary=[ordered]@{ started_at=(Get-Date).ToString('o'); stages=@(); warnings=@() }; $cfgDir=Join-Path $HOME '.kbframework'; if(-not(Test-Path -LiteralPath $cfgDir)){New-Item -ItemType Directory -Path $cfgDir -Force|Out-Null}
    $detected=if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'hosts\copilot-cli\HOST-NOTES.md')){'copilot-cli'}else{'opencode'}; $hostChoice=Ask 'Which host? (copilot-cli/opencode)' $detected; if($hostChoice -notin @('copilot-cli','opencode')){$hostChoice=$detected}; $pref=Join-Path $cfgDir 'host_preference.yaml'; @("host: $hostChoice","updated: $(Get-Date -Format yyyy-MM-dd)")|Set-Content -LiteralPath $pref -Encoding UTF8; $summary.stages += [pscustomobject]@{ stage='host'; status='ok'; detail="Host preference written: $pref" }
    $providers=@('copilot-cli','azure-foundry','openrouter','ollama'); $chosen=@(); foreach($p in $providers){ $use=Ask "Configure provider $p? (yes/no)" 'yes'; if($use -match '^(y|yes)$'){$chosen += $p} }
    foreach($p in $chosen){ $needed=switch($p){ 'copilot-cli' {@('COPILOT_CLI_ENDPOINT','COPILOT_CLI_TOKEN')} 'azure-foundry' {@('AZURE_FOUNDRY_ENDPOINT','AZURE_FOUNDRY_API_KEY')} 'openrouter' {@('OPENROUTER_ENDPOINT','OPENROUTER_API_KEY')} 'ollama' {@('OLLAMA_ENDPOINT')} }; foreach($envName in $needed){ if($null -eq [Environment]::GetEnvironmentVariable($envName)){ $summary.warnings += "Env var not set: $envName"; if(-not $NonInteractive){ Write-Warning "Set $envName in your shell/profile if you will use $p handles." } } } }
    $summary.stages += [pscustomobject]@{ stage='providers'; status='ok'; configured=$chosen }
    $cacheDir=Join-Path $cfgDir 'discovery'; if(-not(Test-Path -LiteralPath $cacheDir)){New-Item -ItemType Directory -Path $cacheDir -Force|Out-Null}; foreach($p in $chosen){ $disc=Join-Path $PSScriptRoot "adapters\model-providers\$p\discover.ps1"; if(Test-Path -LiteralPath $disc){ try{ $out=Join-Path $cacheDir "$p.json"; if($p -eq 'ollama'){& $disc -OutPath $out|Out-Null}else{& $disc -OutPath $out|Out-Null}; $summary.stages += [pscustomobject]@{ stage='discover'; provider=$p; status='ok'; out_path=$out } }catch{ $summary.stages += [pscustomobject]@{ stage='discover'; provider=$p; status='warn'; detail=$_.Exception.Message } } } }
    $rec=Ask 'Get starter model recommendations? (yes/no)' 'yes'; if($rec -match '^(y|yes)$'){ try{ $recPath=Join-Path $cacheDir 'starter-recommendations.json'; & (Join-Path $PSScriptRoot 'Recommend-Models.ps1') -Role ALL -Provider ALL -Domain ANY -TopN 3 -OutPath $recPath | Out-Null; $summary.stages += [pscustomobject]@{ stage='recommend'; status='ok'; out_path=$recPath } }catch{ $summary.stages += [pscustomobject]@{ stage='recommend'; status='warn'; detail=$_.Exception.Message } } }
    $testPath=Join-Path $cacheDir 'test-setup.json'; & (Join-Path $PSScriptRoot 'Test-Setup.ps1') -OutPath $testPath | Out-Null; $setupCode=$LASTEXITCODE; $summary.stages += [pscustomobject]@{ stage='validate'; status=if($setupCode -eq 0){'ok'}else{'warn'}; out_path=$testPath }
    if(-not $SkipSmokeBuild){ $smoke=Ask 'Run a 5-topic smoke build now? (yes/no)' 'no'; if($smoke -match '^(y|yes)$'){ $summary.stages += [pscustomobject]@{ stage='smoke-build'; status='manual'; detail='No generic smoke-build dispatcher is shipped at L3.5; run the selected host orchestrator with a 5-topic scoping report.' } } }
    $summary.completed_at=(Get-Date).ToString('o'); if($OutPath){Write-Json $summary $OutPath}else{Write-Host '# Framework Initialization Summary'; $summary.stages|ForEach-Object{Write-Host "- $($_.stage): $($_.status) $($_.detail)"}; foreach($w in $summary.warnings){Write-Warning $w}}; if($setupCode -gt 1){exit 1}; exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }
