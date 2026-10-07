# Title: Show-BuildStatus.ps1 — live KB build progress viewer.
# Purpose: Parse pipeline_state.md for current phase, running sub-agents, and latest events.
# Inputs: -KBRoot plus optional -Watch and structured -OutPath.
# Outputs: Markdown status snapshot or JSON/YAML status at -OutPath.
# Exit codes: 0 status displayed; 1 pipeline state missing or unreadable.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$KBRoot,
    [Parameter(Mandatory=$false)][switch]$Watch,
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
function Test-Scalar { param($Value) return (($null -eq $Value) -or ($Value -is [string]) -or ($Value -is [int]) -or ($Value -is [long]) -or ($Value -is [double]) -or ($Value -is [bool])) }
function Format-YamlScalar { param($Value) if($null -eq $Value){'null'} elseif($Value -is [bool]){$Value.ToString().ToLowerInvariant()} elseif($Value -is [int] -or $Value -is [long] -or $Value -is [double]){[string]$Value}else{$t=[string]$Value;if($t -match '[:#\[\]{},&*?]|^\s|\s$|\|'){'"'+($t -replace '"','\"')+'"'}else{$t}} }
function ConvertTo-SimpleYaml { param($Value,[int]$Indent=0) $s=' '*$Indent;$l=New-Object System.Collections.Generic.List[string];if(Test-Scalar $Value){$l.Add($s+(Format-YamlScalar $Value))|Out-Null}elseif($Value -is [System.Collections.IDictionary]){foreach($k in $Value.Keys){$i=$Value[$k];if(Test-Scalar $i){$l.Add(('{0}{1}: {2}'-f$s,$k,(Format-YamlScalar $i)))|Out-Null}else{$l.Add(('{0}{1}:'-f$s,$k))|Out-Null;foreach($line in ConvertTo-SimpleYaml $i ($Indent+2)){$l.Add($line)|Out-Null}}}}elseif($Value -is [System.Collections.IEnumerable] -and -not($Value -is [string])){foreach($i in $Value){if(Test-Scalar $i){$l.Add(('{0}- {1}'-f$s,(Format-YamlScalar $i)))|Out-Null}else{$l.Add(('{0}-'-f$s))|Out-Null;foreach($line in ConvertTo-SimpleYaml $i ($Indent+2)){$l.Add($line)|Out-Null}}}}else{$m=[ordered]@{};foreach($p in $Value.PSObject.Properties){$m[$p.Name]=$p.Value};foreach($line in ConvertTo-SimpleYaml $m $Indent){$l.Add($line)|Out-Null}};return @($l)}
function Write-StructuredOutput { param($Data,[string]$Path) $parent=Split-Path -Parent $Path;if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};if($Path -match '\.ya?ml$'){(ConvertTo-SimpleYaml $Data)-join[Environment]::NewLine|Set-Content -LiteralPath $Path -Encoding UTF8}else{$Data|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8} }
function Get-BuildStatus { param([string]$Root)
    $statePath=Join-Path $Root 'sources\pipeline_state.md'
    if(-not(Test-Path -LiteralPath $statePath)){throw "pipeline_state.md not found: $statePath"}
    $text=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
    $current='unknown'
    foreach($pat in @('(?im)^\s*current_phase\s*:\s*(.+?)\s*$','(?im)^\s*phase\s*:\s*(.+?)\s*$','(?im)^\s*##\s*(Phase[^\r\n]+)')){ if($text -match $pat){$current=$matches[1].Trim();break} }
    $agents=@(); foreach($m in [regex]::Matches($text,'(?im)^\s*(?:[-*]\s*)?(?:agent|sub-agent|subagent)\s*[:\-]\s*(.+?)(?:\s+status\s*[:=]\s*(running|in_progress|active))?\s*$')){ $agents += $m.Groups[1].Value.Trim() }
    if($agents.Count -eq 0){ foreach($m in [regex]::Matches($text,'(?im)^\s*(?:[-*]\s*)?(.{0,80}?(?:running|in_progress|active).{0,80})$')){ if($m.Groups[1].Value -match '(agent|builder|critic|auditor|fact)'){ $agents += $m.Groups[1].Value.Trim() } } }
    $eventLines=@(); foreach($line in ($text -split "`r?`n")){ if($line -match '(?i)(event|started|completed|failed|dispatched|resumed|phase)'){ $eventLines += $line.Trim() } }
    [ordered]@{ kb_root=$Root; state_path=$statePath; checked_at=(Get-Date).ToString('o'); current_phase=$current; running_subagents=@($agents|Select-Object -Unique); last_events=@($eventLines|Select-Object -Last 5) }
}
function Show-Human { param($Status) Write-Host '# Build Status'; Write-Host "KBRoot: $($Status.kb_root)"; Write-Host "Checked: $($Status.checked_at)"; Write-Host "Current phase: $($Status.current_phase)"; Write-Host ''; Write-Host '## Running sub-agents'; if($Status.running_subagents.Count){foreach($a in $Status.running_subagents){Write-Host "- $a"}}else{Write-Host '_None parsed from pipeline_state._'}; Write-Host ''; Write-Host '## Last 5 events'; if($Status.last_events.Count){foreach($e in $Status.last_events){Write-Host "- $e"}}else{Write-Host '_No event lines parsed._'} }
try { if(-not(Test-Path -LiteralPath $KBRoot -PathType Container)){throw "KBRoot not found: $KBRoot"}; $KBRoot=(Resolve-Path -LiteralPath $KBRoot).Path; do { $status=Get-BuildStatus $KBRoot; if($OutPath){Write-StructuredOutput $status $OutPath}else{if($Watch){Clear-Host}; Show-Human $status}; if($Watch){Start-Sleep -Seconds 2} } while($Watch); exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }
