param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia",[int]$Puerto=3000,[string]$SourceConfigPath,[switch]$NoPause)
$ErrorActionPreference='Stop'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){Write-Host 'Cierra esta ventana. Haz clic derecho en INSTALAR.cmd y elige Ejecutar como administrador.' -ForegroundColor Yellow;Read-Host 'Pulsa Enter';exit 1}
if($Puerto -lt 1024 -or $Puerto -gt 65535){throw 'El puerto debe estar entre 1024 y 65535.'}
if($env:PROCESSOR_ARCHITECTURE -ne 'AMD64'){throw 'Este paquete requiere Windows de 64 bits (x64).'}
$source=$PSScriptRoot
foreach($required in @('app/server.js','runtime/node.exe','configuracion.json','Iniciar-CRM.ps1')){if(-not(Test-Path -LiteralPath (Join-Path $source $required))){throw "Falta $required. Extrae todo el ZIP antes de instalar."}}
$version=Get-Date -Format 'yyyyMMdd-HHmmss'
$destination=Join-Path $InstallRoot "versiones\$version"
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Write-Host 'Preparando CRM Tecnologia para la red local...'
foreach($item in @('app','runtime','configuracion.json','Iniciar-CRM.ps1','version.json')){Copy-Item -LiteralPath (Join-Path $source $item) -Destination $destination -Recurse -Force}
$configPath=Join-Path $destination 'configuracion.json'
if($SourceConfigPath){Copy-Item -LiteralPath $SourceConfigPath -Destination $configPath -Force}
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$allowedSubnets=@('LocalSubnet')
if($config.allowedSubnets){$allowedSubnets=@($config.allowedSubnets)}
$config.puerto=$Puerto
$config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
$taskName='CRM-Tecnologia'
$oldTask=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if($oldTask){Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue}
$versionsRoot=[IO.Path]::GetFullPath((Join-Path $InstallRoot 'versiones'))+'\'
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versionsRoot,[StringComparison]::OrdinalIgnoreCase)} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
$startScript=Join-Path $destination 'Iniciar-CRM.ps1'
$arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$startScript+'"'
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments -WorkingDirectory $destination
$trigger=New-ScheduledTaskTrigger -AtStartup
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
$runAs=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $runAs -Description 'CRM Tecnologia en la red local' -Force | Out-Null
$rule='CRM-Tecnologia-LAN'
if(Get-NetFirewallRule -Name $rule -ErrorAction SilentlyContinue){Set-NetFirewallRule -Name $rule -Enabled True -Profile Domain,Private -Action Allow -RemoteAddress $allowedSubnets;Get-NetFirewallRule -Name $rule | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -Protocol TCP -LocalPort $Puerto}
else{New-NetFirewallRule -Name $rule -DisplayName 'CRM Tecnologia - red local' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Puerto -RemoteAddress $allowedSubnets -Profile Domain,Private -Program (Join-Path $destination 'runtime/node.exe') | Out-Null}
Get-NetFirewallRule -Name $rule | Get-NetFirewallApplicationFilter | Set-NetFirewallApplicationFilter -Program (Join-Path $destination 'runtime/node.exe')
Start-ScheduledTask -TaskName $taskName
$healthy=$false
for($attempt=0;$attempt -lt 30;$attempt++){try{$response=Invoke-WebRequest -Uri "http://127.0.0.1:$Puerto/login" -UseBasicParsing -TimeoutSec 2;if($response.StatusCode -eq 200){if($config.storage -eq 'local'){if(-not((Invoke-RestMethod -Uri "http://127.0.0.1:$Puerto/api/local/status" -TimeoutSec 2).local)){throw 'No se confirmo almacenamiento local.'}};$healthy=$true;break}}catch{};Start-Sleep -Seconds 1}
if(-not $healthy){throw "No se pudo iniciar el CRM. Revisa $destination\logs\errores.log"}
$packageVersion=Get-Content -LiteralPath (Join-Path $destination 'version.json') -Raw | ConvertFrom-Json
@{path=$destination;puerto=$Puerto;commit=$packageVersion.commit} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallRoot 'activo.json') -Encoding UTF8
$routes=Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric
$addresses=@(foreach($route in $routes){Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1'} | Select-Object -ExpandProperty IPAddress}) | Select-Object -Unique
$urls=@($addresses | ForEach-Object {"http://$($_):$Puerto"})
if($config.storage -eq 'local'){try{$privateConfig=Get-Content (Join-Path $config.dataDirectory 'privado.json') -Raw|ConvertFrom-Json;if($privateConfig.appUrl){$urls=@($privateConfig.appUrl)}}catch{}}
@('CRM Tecnologia instalado.','','Abre desde otra PC de la misma red:')+$urls+@('','Envia esta direccion a Samuel/Codex para completar el retorno de inicio de sesion y los enlaces de correo.',$(if($config.storage -eq 'local'){'La informacion se guarda en esta PC. Mantenla encendida. Internet se utiliza para correos y actualizaciones.'}else{'La PC servidora debe permanecer encendida y conectada a Internet para Supabase.'}),'Vercel se retirara despues de verificar el acceso desde ambas computadoras.',"Carpeta de instalacion: $destination") | Set-Content -LiteralPath (Join-Path $InstallRoot 'ACCESO-CRM.txt') -Encoding UTF8
if($config.storage -eq 'local'){$tools=Join-Path $InstallRoot 'herramientas';New-Item -ItemType Directory -Path $tools -Force|Out-Null;foreach($helper in @('Mantenimiento-Local.ps1','Restaurar-Copia.cjs','Restaurar-Copia.ps1','Configurar-Copia-Externa.ps1','OPERACION-Y-RECUPERACION.txt')){if(Test-Path (Join-Path $source $helper)){Copy-Item (Join-Path $source $helper) $tools -Force}}}
Write-Host 'CRM instalado y funcionando.' -ForegroundColor Green
$urls | ForEach-Object {Write-Host $_ -ForegroundColor Cyan}
Write-Host "Datos de acceso guardados en $InstallRoot\ACCESO-CRM.txt"
if(-not $NoPause){Read-Host 'Pulsa Enter para cerrar'}
