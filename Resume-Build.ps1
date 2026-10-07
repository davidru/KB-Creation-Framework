# Title: Resume-Build.ps1 — resumable KB build dispatcher.
# Purpose: Read pipeline state, compute resume phase, confirm, and invoke an available dispatcher.
# Inputs: -KBRoot, optional -FromPhase override, and structured -OutPath.
# Outputs: Resume plan and execution status in Markdown or JSON/YAML.
# Exit codes: 0 plan emitted/dispatch attempted; 1 state missing, malformed, or dispatch refused.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$KBRoot,
    [Parameter(Mandatory=$false)][string]$FromPhase = '',
    [Parameter(Mandatory=$false)][string]$OutPath = '',
    [Parameter(Mandatory=$false)][switch]$Help
)

if ($Help -or (-not $KBRoot)) {
    Write-Host @"
Resume-Build.ps1 — resumable KB build dispatcher

Usage:
    Resume-Build.ps1 -KBRoot <path> [-FromPhase <phase>] [-OutPath <path>]
    Resume-Build.ps1 -Help

Parameters:
    -KBRoot     Mandatory. Absolute path to the KB build root directory.
                Must contain sources\pipeline_state.md.
    -FromPhase  Optional. Override the auto-detected resume phase.
                Useful when pipeline_state.md is malformed or the
                operator wants to re-run a specific phase.
    -OutPath    Optional. If provided, the resume plan is written as
                structured JSON to this path. Otherwise emitted to stdout.
    -Help       Print this help and exit 0.

Behavior:
    Reads <KBRoot>\sources\pipeline_state.md, identifies the last
    completed phase, and emits a resume plan for the next pending
    phase. Refuses to resume if pipeline_state.md is missing,
    empty, or malformed (no parseable phase progression).

Exit codes:
    0  Resume plan emitted (or dispatch attempted)
    1  pipeline_state.md missing/malformed, or dispatch refused
"@
    if ($Help) { exit 0 }
    Write-Error 'KBRoot is required. Run with -Help for usage.'
    exit 1
}

$ErrorActionPreference = 'Stop'
function Write-StructuredOutput { param($Data,[string]$Path) $parent=Split-Path -Parent $Path;if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$Data|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Get-StatePlan { param([string]$Root,[string]$Override)
    $statePath=Join-Path $Root 'sources\pipeline_state.md'
    if(-not(Test-Path -LiteralPath $statePath)){throw "Refusing to resume: pipeline_state.md missing at $statePath"}
    $text=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
    if([string]::IsNullOrWhiteSpace($text)){throw 'Refusing to resume: pipeline_state.md is empty.'}
    if($text -notmatch '(?is)model_assignment'){throw 'Refusing to resume: pipeline_state.md has no persisted model_assignment block.'}
    $completed=@(); foreach($m in [regex]::Matches($text,'(?im)^\s*(?:[-*]\s*)?(Phase\s*[0-9][A-Za-z0-9_.\- ]*)\s*[:\-].*\b(completed|complete|done|PASS)\b')){ $completed += ($m.Groups[1].Value.Trim() -replace '\s+',' ') }
    $current=''; if($text -match '(?im)^\s*current_phase\s*:\s*(.+?)\s*$'){$current=$matches[1].Trim()}
    if(-not $completed.Count -and -not $current -and -not $Override){throw 'Refusing to resume: pipeline_state.md is malformed (no completed/current phase parsed).'}
    $phaseOrder=@('Phase 0.0','Phase 1','Phase 2','Phase 3','Phase 4','Phase 5','Phase 5d','Phase 5e','Phase 6','Phase 6b','Phase 7','Phase 8')
    $last=if($completed.Count){$completed[-1]}elseif($current){$current}else{'Phase 0.0'}
    $resume=$Override
    if(-not $resume){ $idx=[array]::IndexOf($phaseOrder,$last); if($idx -ge 0 -and $idx -lt ($phaseOrder.Count-1)){$resume=$phaseOrder[$idx+1]} elseif($current){$resume=$current}else{$resume=$last} }
    [ordered]@{ kb_root=$Root; state_path=$statePath; last_completed_phase=$last; current_phase=$current; resume_from_phase=$resume; completed_phases=$completed; model_assignment_excerpt=(([regex]::Match($text,'(?is)model_assignment\s*:?.{0,2000}')).Value.Trim()) }
}
function Show-Plan { param($Plan) Write-Host '# Resume Plan'; Write-Host "KBRoot: $($Plan.kb_root)"; Write-Host "State: $($Plan.state_path)"; Write-Host "Last completed: $($Plan.last_completed_phase)"; Write-Host "Current phase: $($Plan.current_phase)"; Write-Host "Resume from: $($Plan.resume_from_phase)"; Write-Host ''; Write-Host '## Model assignment excerpt'; Write-Host '```text'; Write-Host $Plan.model_assignment_excerpt; Write-Host '```' }
try { if(-not(Test-Path -LiteralPath $KBRoot -PathType Container)){throw "KBRoot not found: $KBRoot"}; $KBRoot=(Resolve-Path -LiteralPath $KBRoot).Path; $plan=Get-StatePlan $KBRoot $FromPhase; $plan.execution_status='not_started'; if($OutPath){Write-StructuredOutput $plan $OutPath}else{Show-Plan $plan}; $answer='yes'; try{$answer=Read-Host 'Resume this build now? (yes/no)'}catch{$answer='no'}; if($answer.Trim().ToLowerInvariant() -ne 'yes'){ $plan.execution_status='operator_declined'; if($OutPath){Write-StructuredOutput $plan $OutPath}; Write-Host 'Resume cancelled.'; exit 1 }
    $dispatcher=Join-Path $PSScriptRoot 'Invoke-BuildPhase.ps1'
    if(Test-Path -LiteralPath $dispatcher){ & $dispatcher -KBRoot $KBRoot -FromPhase $plan.resume_from_phase; $plan.execution_status=if($LASTEXITCODE -eq 0){'dispatched'}else{"dispatcher_failed_$LASTEXITCODE"}; if($LASTEXITCODE -ne 0){exit $LASTEXITCODE} } else { $plan.execution_status='manual_dispatch_required'; $plan.dispatch_note='Invoke-BuildPhase.ps1 is not present in this framework root; plan emitted for the active host/orchestrator to dispatch with persisted model_assignment.'; Write-Warning $plan.dispatch_note }
    if($OutPath){Write-StructuredOutput $plan $OutPath}; exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }
