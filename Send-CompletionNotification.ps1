# Title: Send-CompletionNotification.ps1 — optional build completion notifier.
# Purpose: Send desktop toast and/or SMTP email when a KB build completes.
# Inputs: Optional KBRoot, Message, Subject, and structured -OutPath.
# Outputs: Silent no-op when unconfigured; otherwise status report or JSON/YAML.
# Exit codes: 0 no-op or notification attempted; 1 configured notification failed.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$KBRoot = '',
    [Parameter(Mandatory=$false)][string]$Subject = 'KB build complete',
    [Parameter(Mandatory=$false)][string]$Message = '',
    [Parameter(Mandatory=$false)][string]$OutPath = ''
)

$ErrorActionPreference = 'Stop'
function Write-Json { param($Data,[string]$Path) $parent=Split-Path -Parent $Path;if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$Data|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Parse-SimpleYamlMap { param([string]$Text) $map=@{}; foreach($line in ($Text -split "`r?`n")){ if($line -match '^\s*([A-Za-z0-9_\-]+)\s*:\s*(.+?)\s*$'){ $map[$matches[1]]=($matches[2].Trim() -replace '^[''\"]|[''\"]$','') } }; return $map }
function Get-Config { param([string]$Root)
    $cfgPath=Join-Path $HOME '.kbframework\notify.yaml'; if(Test-Path -LiteralPath $cfgPath){return [pscustomobject]@{ source=$cfgPath; values=(Parse-SimpleYamlMap (Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8)) }}
    if($Root){$scope=Join-Path $Root 'sources\scoping_report.md'; if(Test-Path -LiteralPath $scope){$txt=Get-Content -LiteralPath $scope -Raw -Encoding UTF8; if($txt -match '(?is)notify_on_completion\s*:\s*(\{.*?\}|.*?)(?:\r?\n\S|\z)'){ $raw=$matches[1]; $vals=Parse-SimpleYamlMap $raw; if($raw -match 'method\s*[:=]\s*([A-Za-z,]+)'){$vals['method']=$matches[1]}; if($raw -match 'recipient\s*[:=]\s*([^,}\r\n]+)'){$vals['recipient']=$matches[1].Trim()}; return [pscustomobject]@{ source=$scope; values=$vals } }}}
    return $null
}
function Send-Toast { param([string]$Title,[string]$Body)
    if(Get-Module -ListAvailable -Name BurntToast){ Import-Module BurntToast -ErrorAction Stop; New-BurntToastNotification -Text $Title,$Body | Out-Null; return 'sent-burnttoast' }
    $escapedTitle = $Title -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
    $escapedBody = $Body -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
    $xml = "<toast><visual><binding template='ToastGeneric'><text>$escapedTitle</text><text>$escapedBody</text></binding></visual></toast>"
    try { [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null; $doc=New-Object Windows.Data.Xml.Dom.XmlDocument; $doc.LoadXml($xml); $notifier=[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('KB Creation Framework'); $toast=[Windows.UI.Notifications.ToastNotification]::new($doc); $notifier.Show($toast); return 'sent-windows-runtime' } catch { throw "Toast unavailable: $($_.Exception.Message)" }
}
function Send-EmailNotice { param($Config,[string]$Title,[string]$Body)
    foreach($k in @('smtp_server','from','recipient')){ if(-not $Config.ContainsKey($k)){throw "Email method requires '$k' in notify.yaml"} }
    $port=if($Config.ContainsKey('smtp_port')){[int]$Config['smtp_port']}else{25}; Send-MailMessage -SmtpServer $Config['smtp_server'] -Port $port -From $Config['from'] -To $Config['recipient'] -Subject $Title -Body $Body; return 'sent-email'
}
try { if($KBRoot -and (Test-Path -LiteralPath $KBRoot -PathType Container)){$KBRoot=(Resolve-Path -LiteralPath $KBRoot).Path}; if(-not $Message){$Message=if($KBRoot){"Build completed for $KBRoot"}else{'KB build completed.'}}
    $configEnvelope=Get-Config $KBRoot; $result=[ordered]@{ generated_at=(Get-Date).ToString('o'); configured=$false; source=$null; attempted=@(); errors=@() }
    if($null -eq $configEnvelope){ if($OutPath){Write-Json $result $OutPath}; exit 0 }
    $cfg=$configEnvelope.values; $result.configured=$true; $result.source=$configEnvelope.source; $method=if($cfg.ContainsKey('method')){$cfg['method']}else{'toast'}; $methods=@($method -split '[,|+]' | ForEach-Object{$_.Trim().ToLowerInvariant()} | Where-Object{$_})
    $stateDir=Join-Path $HOME '.kbframework'; if(-not(Test-Path -LiteralPath $stateDir)){New-Item -ItemType Directory -Path $stateDir -Force|Out-Null}; $hash=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Subject+$Message+$KBRoot))).Substring(0,16); $statePath=Join-Path $stateDir 'notification-state.json'; if(Test-Path -LiteralPath $statePath){$old=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction SilentlyContinue; if($old.last_hash -eq $hash){$result.attempted += 'duplicate-suppressed'; if($OutPath){Write-Json $result $OutPath}; exit 0}}
    foreach($m in $methods){ try{ switch($m){ 'toast' { $result.attempted += (Send-Toast $Subject $Message) } 'email' { $result.attempted += (Send-EmailNotice $cfg $Subject $Message) } 'both' { $result.attempted += (Send-Toast $Subject $Message); $result.attempted += (Send-EmailNotice $cfg $Subject $Message) } default { $result.errors += "Unknown notification method: $m" } } }catch{ $result.errors += $_.Exception.Message } }
    [ordered]@{ last_hash=$hash; sent_at=(Get-Date).ToString('o'); subject=$Subject }|ConvertTo-Json|Set-Content -LiteralPath $statePath -Encoding UTF8
    if($OutPath){Write-Json $result $OutPath}else{foreach($a in $result.attempted){Write-Host $a}; foreach($e in $result.errors){Write-Warning $e}}
    if($result.errors.Count -gt 0){exit 1}; exit 0 } catch { Write-Error $_.Exception.Message; exit 1 }
