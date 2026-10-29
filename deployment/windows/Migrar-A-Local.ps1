param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Ejecuta MIGRAR-A-LOCAL.cmd como administrador.'}
$snapshot=Join-Path $PSScriptRoot 'migracion-crm.json'
if(-not(Test-Path -LiteralPath $snapshot)){throw 'Falta migracion-crm.json. Usa el paquete privado de migracion, que incluye los datos actuales.'}
$active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw | ConvertFrom-Json
$oldConfig=Get-Content (Join-Path $active.path 'configuracion.json') -Raw | ConvertFrom-Json

$dataDirectory=Join-Path $InstallRoot 'datos'
if(Test-Path (Join-Path $dataDirectory 'crm.sqlite')){& (Join-Path $PSScriptRoot 'Reparar-Migracion-Local.ps1') -InstallRoot $InstallRoot;return}
New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
& icacls.exe $dataDirectory /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if($LASTEXITCODE -ne 0){throw 'No se pudo proteger la carpeta de datos.'}
& (Join-Path $PSScriptRoot 'runtime/node.exe') (Join-Path $PSScriptRoot 'Importar-Local.cjs') $snapshot $dataDirectory
if($LASTEXITCODE -ne 0){throw 'No se pudo importar la base de datos. El CRM anterior no se ha reemplazado.'}
$secretBytes=New-Object byte[] 32
$generator=[Security.Cryptography.RandomNumberGenerator]::Create();$generator.GetBytes($secretBytes);$generator.Dispose()
$maintenanceSecret=[Convert]::ToBase64String($secretBytes)
$appUrl=Read-Host 'Direccion del CRM [http://10.0.0.159:3000]'
if(-not $appUrl){$appUrl='http://10.0.0.159:3000'}
$uri=$null;if(-not [Uri]::TryCreate($appUrl,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('http','https')){throw 'Direccion invalida.'}
Write-Host 'Para conservar los avisos por correo, escribe la clave del correo sroa@grupodupla.com. No aparece en pantalla.'
$smtpSecret=Read-Host 'Clave del correo (Enter permite configurarla despues)' -AsSecureString
$smtpPassword=[Net.NetworkCredential]::new('',$smtpSecret).Password
@{maintenanceSecret=$maintenanceSecret;appUrl=$appUrl;smtp=@{host='mail.gdlinea.com';user='sroa@grupodupla.com';password=$smtpPassword}} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $dataDirectory 'privado.json') -Encoding UTF8
$smtpPassword=$null
$allowedSubnets=@('LocalSubnet')+@($oldConfig.allowedSubnets)+@('10.1.0.154/32') | Where-Object {$_} | Select-Object -Unique
@{storage='local';dataDirectory=$dataDirectory;puerto=$active.puerto;supabaseUrl='';supabasePublishableKey='';allowedSubnets=@($allowedSubnets)} | ConvertTo-Json | Set-Content (Join-Path $dataDirectory 'configuracion-local.json') -Encoding UTF8
$oldXml=Export-ScheduledTask -TaskName 'CRM-Tecnologia'
$updater=Get-ScheduledTask -TaskName 'CRM-Tecnologia-Actualizaciones' -ErrorAction SilentlyContinue
if($updater){Disable-ScheduledTask -TaskName 'CRM-Tecnologia-Actualizaciones' | Out-Null}
try{
 & (Join-Path $PSScriptRoot 'Instalar-CRM.ps1') -InstallRoot $InstallRoot -Puerto $active.puerto -SourceConfigPath (Join-Path $dataDirectory 'configuracion-local.json') -NoPause
 $status=Invoke-WebRequest -Uri "http://127.0.0.1:$($active.puerto)/api/local/status" -UseBasicParsing
 if(-not(($status.Content|ConvertFrom-Json).local)){throw 'La nueva version no confirmo la base local.'}
 $tools=Join-Path $InstallRoot 'herramientas';New-Item -ItemType Directory -Path $tools -Force | Out-Null
 Copy-Item (Join-Path $PSScriptRoot 'Mantenimiento-Local.ps1') $tools -Force
 $arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $tools 'Mantenimiento-Local.ps1')+'" -InstallRoot "'+$InstallRoot+'"'
 $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments
 $trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
 $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
 $runAs=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
 Register-ScheduledTask -TaskName 'CRM-Tecnologia-Mantenimiento' -Action $action -Trigger $trigger -Settings $settings -Principal $runAs -Force | Out-Null
 Start-ScheduledTask -TaskName 'CRM-Tecnologia-Mantenimiento'
 if($updater){Enable-ScheduledTask -TaskName 'CRM-Tecnologia-Actualizaciones' | Out-Null}
 Write-Host 'CRM migrado a la base local. Usuarios y contrasenas conservados.' -ForegroundColor Green
 Write-Host "Datos: $dataDirectory\crm.sqlite"
 Write-Host "Acceso: $appUrl"
 Write-Host 'Entra con Samuel y Elvis, revisa las tareas y confirma en el chat antes de retirar Vercel.'
 if(-not $smtpSecret.Length){Write-Host 'Pendiente: configurar la clave SMTP para los avisos por correo.' -ForegroundColor Yellow}
}catch{
 $originalFailure=$_.Exception.Message
 Add-Content (Join-Path $InstallRoot 'reparacion-local.log') ((Get-Date -Format s)+' Error original de migracion: '+$originalFailure)
 Write-Host ('Detalle original: '+$originalFailure) -ForegroundColor Yellow
 Stop-ScheduledTask -TaskName 'CRM-Tecnologia' -ErrorAction SilentlyContinue
 $versionsRoot=[IO.Path]::GetFullPath((Join-Path $InstallRoot 'versiones'))+'\'
 Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versionsRoot,[StringComparison]::OrdinalIgnoreCase)} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
 Register-ScheduledTask -TaskName 'CRM-Tecnologia' -Xml $oldXml -Force | Out-Null
 Get-NetFirewallRule -Name 'CRM-Tecnologia-LAN' | Get-NetFirewallApplicationFilter | Set-NetFirewallApplicationFilter -Program (Join-Path $active.path 'runtime/node.exe')
 $active | ConvertTo-Json | Set-Content (Join-Path $InstallRoot 'activo.json') -Encoding UTF8
 Start-ScheduledTask -TaskName 'CRM-Tecnologia'
 throw 'No termino la migracion. Se restauro el arranque anterior y se conservaron los archivos para revision.'
}
Read-Host 'Pulsa Enter para cerrar'
