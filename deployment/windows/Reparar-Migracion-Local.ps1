param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Ejecuta REPARAR-MIGRACION-LOCAL.cmd como administrador en la PC servidora.'}
$log=Join-Path $InstallRoot 'reparacion-local.log'
function Record([string]$Text){Add-Content -LiteralPath $log -Value ((Get-Date -Format s)+' '+$Text);Write-Host $Text}
Add-Type -AssemblyName System.Net.Http
function LocalStatus([int]$Port){
 $handler=New-Object Net.Http.HttpClientHandler;$handler.UseProxy=$false
 $client=New-Object Net.Http.HttpClient($handler);$client.Timeout=[TimeSpan]::FromSeconds(4)
 try{$reply=$client.GetAsync("http://127.0.0.1:$Port/api/local/status?check=$([Guid]::NewGuid().ToString('N'))").GetAwaiter().GetResult();if(-not $reply.IsSuccessStatusCode){throw "Comprobacion local: HTTP $([int]$reply.StatusCode)"};return ($reply.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json)}finally{$client.Dispose();$handler.Dispose()}
}
$oldXml=$null;$oldActive=$null;$switched=$false;$coreReady=$false
try{
 $dataDirectory=Join-Path $InstallRoot 'datos'
 foreach($file in @('crm.sqlite','privado.json','configuracion-local.json')){if(-not(Test-Path -LiteralPath (Join-Path $dataDirectory $file))){throw "Falta $file en la carpeta de datos. No se modifico la base."}}
 $oldActive=Get-Content -LiteralPath (Join-Path $InstallRoot 'activo.json') -Raw|ConvertFrom-Json
 $versionsRoot=[IO.Path]::GetFullPath((Join-Path $InstallRoot 'versiones'))+'\'
 $candidate=@(Get-ChildItem -LiteralPath (Join-Path $InstallRoot 'versiones') -Directory|Sort-Object LastWriteTime -Descending|Where-Object {
  $configPath=Join-Path $_.FullName 'configuracion.json'
  if(Test-Path -LiteralPath $configPath){try{$candidateConfig=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json; $candidateConfig.storage -eq 'local' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'app/server.js')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'Iniciar-CRM.ps1'))}catch{$false}}
 })|Select-Object -First 1
 if(-not $candidate){throw 'No se encontro la version local instalada. Conserva la carpeta del paquete de migracion y envia este mensaje.'}
 $root=[IO.Path]::GetFullPath($candidate.FullName)
 if(-not $root.StartsWith($versionsRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Carpeta de version fuera del CRM.'}
 $node=Join-Path $root 'runtime/node.exe'
 $checkScript=Join-Path $PSScriptRoot 'Comprobar-Base-Local.cjs'
 Record 'Comprobando la base existente y creando una copia de seguridad...'
 & $node $checkScript $dataDirectory
 if($LASTEXITCODE -ne 0){throw 'No paso la comprobacion de la base local. No se reemplazaron datos.'}
 $config=Get-Content -LiteralPath (Join-Path $dataDirectory 'configuracion-local.json') -Raw|ConvertFrom-Json
 if($config.storage -ne 'local' -or [IO.Path]::GetFullPath($config.dataDirectory) -ne [IO.Path]::GetFullPath($dataDirectory)){throw 'La configuracion no apunta a la base local esperada.'}
 $port=[int]$config.puerto;if($port -lt 1024 -or $port -gt 65535){throw 'Puerto local invalido.'}
 Copy-Item -LiteralPath (Join-Path $dataDirectory 'configuracion-local.json') -Destination (Join-Path $root 'configuracion.json') -Force
 $oldXml=Export-ScheduledTask -TaskName 'CRM-Tecnologia'
 $switched=$true
 Stop-ScheduledTask -TaskName 'CRM-Tecnologia' -ErrorAction SilentlyContinue
 Get-CimInstance Win32_Process -Filter "Name='node.exe'"|Where-Object{$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versionsRoot,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
 $arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $root 'Iniciar-CRM.ps1')+'"'
 $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments -WorkingDirectory $root
 $trigger=New-ScheduledTaskTrigger -AtStartup
 $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
 $runAs=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
 Register-ScheduledTask -TaskName 'CRM-Tecnologia' -Action $action -Trigger $trigger -Settings $settings -Principal $runAs -Force|Out-Null
 $allowed=@('LocalSubnet','10.1.0.154/32')+@($config.allowedSubnets)|Where-Object{$_}|Select-Object -Unique
 Set-NetFirewallRule -Name 'CRM-Tecnologia-LAN' -Enabled True -Profile Domain,Private -Action Allow -RemoteAddress $allowed
 Get-NetFirewallRule -Name 'CRM-Tecnologia-LAN'|Get-NetFirewallApplicationFilter|Set-NetFirewallApplicationFilter -Program $node
 Get-NetFirewallRule -Name 'CRM-Tecnologia-LAN'|Get-NetFirewallPortFilter|Set-NetFirewallPortFilter -Protocol TCP -LocalPort $port
 Start-ScheduledTask -TaskName 'CRM-Tecnologia'
 $healthy=$false;$lastReason='Sin respuesta'
 for($attempt=0;$attempt -lt 30;$attempt++){try{$status=LocalStatus $port;if($status.local -eq $true){$healthy=$true;break};$lastReason='El servidor respondio sin confirmar almacenamiento local'}catch{$lastReason=$_.Exception.Message};Start-Sleep -Seconds 1}
 if(-not $healthy){throw "No se pudo confirmar el arranque local: $lastReason. Revisa $root\logs\errores.log"}
 @{path=$root;puerto=$port;commit=(Get-Content (Join-Path $root 'version.json') -Raw|ConvertFrom-Json).commit}|ConvertTo-Json|Set-Content (Join-Path $InstallRoot 'activo.json') -Encoding UTF8
 $coreReady=$true
 Record 'BASE LOCAL ACTIVA. Se conservaron usuarios, contrasenas y tareas.'
 try{
  $tools=Join-Path $InstallRoot 'herramientas';New-Item -ItemType Directory -Path $tools -Force|Out-Null
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Mantenimiento-Local.ps1') -Destination $tools -Force
  $argsTask='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $tools 'Mantenimiento-Local.ps1')+'" -InstallRoot "'+$InstallRoot+'"'
  $maintenanceAction=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $argsTask
  $maintenanceTrigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
  $maintenanceSettings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName 'CRM-Tecnologia-Mantenimiento' -Action $maintenanceAction -Trigger $maintenanceTrigger -Settings $maintenanceSettings -Principal $runAs -Force|Out-Null
  Start-ScheduledTask -TaskName 'CRM-Tecnologia-Mantenimiento'
  Record 'Mantenimiento y avisos programados.'
 }catch{Record ('La base local funciona. Pendiente programar mantenimiento: '+$_.Exception.Message)}
 try{if(Get-ScheduledTask -TaskName 'CRM-Tecnologia-Actualizaciones' -ErrorAction SilentlyContinue){Enable-ScheduledTask -TaskName 'CRM-Tecnologia-Actualizaciones'|Out-Null;Record 'Actualizaciones de GitHub reactivadas.'}}catch{Record ('Pendiente reactivar actualizaciones: '+$_.Exception.Message)}
 Record "Abre http://10.0.0.159:$port e inicia sesion con tus datos habituales."
 Record "Base: $dataDirectory\crm.sqlite"
}catch{
 $reason=$_.Exception.Message
 if($switched -and -not $coreReady -and $oldXml){try{Stop-ScheduledTask -TaskName 'CRM-Tecnologia' -ErrorAction SilentlyContinue;Get-CimInstance Win32_Process -Filter "Name='node.exe'"|Where-Object{$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versionsRoot,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue};Register-ScheduledTask -TaskName 'CRM-Tecnologia' -Xml $oldXml -Force|Out-Null;Get-NetFirewallRule -Name 'CRM-Tecnologia-LAN'|Get-NetFirewallApplicationFilter|Set-NetFirewallApplicationFilter -Program (Join-Path $oldActive.path 'runtime/node.exe');$oldActive|ConvertTo-Json|Set-Content (Join-Path $InstallRoot 'activo.json') -Encoding UTF8;Start-ScheduledTask -TaskName 'CRM-Tecnologia';Record 'Se restauro el arranque anterior. La base importada permanece intacta.'}catch{Record 'No se pudo restaurar el arranque. Los datos permanecen intactos.'}}
 Record ('ERROR REAL: '+$reason)
 Record "Copia este mensaje al chat. Registro: $log"
 Read-Host 'Pulsa Enter para cerrar';exit 1
}
Read-Host 'Pulsa Enter para cerrar'
