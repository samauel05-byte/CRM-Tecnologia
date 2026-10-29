param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Ejecuta ACTIVAR-ACTUALIZACIONES.cmd como administrador.'}
if(-not(Test-Path (Join-Path $InstallRoot 'activo.json'))){throw 'Instala primero este paquete actualizado del CRM.'}
$gh=Get-Command gh.exe -ErrorAction SilentlyContinue
if(-not $gh){Write-Host 'Instala GitHub CLI desde https://cli.github.com y vuelve a ejecutar este archivo.';Start-Process 'https://cli.github.com';Read-Host 'Pulsa Enter';exit 1}
& $gh.Source auth status --hostname github.com
if($LASTEXITCODE -ne 0){Write-Host 'Inicia sesion con la cuenta que tiene acceso a CRM-Tecnologia. La clave no se guarda en el CRM.';& $gh.Source auth login --hostname github.com --git-protocol https --web;if($LASTEXITCODE -ne 0){throw 'No se completo el inicio de sesion.'}}
& $gh.Source api repos/samauel05-byte/CRM-Tecnologia --silent
if($LASTEXITCODE -ne 0){throw 'Esta cuenta no puede consultar la repo del CRM.'}
$target=Join-Path $InstallRoot 'actualizador'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'Actualizar-CRM.ps1') $target -Force
@{gh=$gh.Source} | ConvertTo-Json | Set-Content (Join-Path $InstallRoot 'actualizador.json') -Encoding UTF8
$arguments='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $target 'Actualizar-CRM.ps1')+'" -InstallRoot "'+$InstallRoot+'"'
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$runAs=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName 'CRM-Tecnologia-Actualizaciones' -Action $action -Trigger $trigger -Settings $settings -Principal $runAs -Description 'Comprueba versiones verificadas de GitHub cada 5 minutos, con la sesion de Windows abierta.' -Force | Out-Null
Write-Host 'Actualizaciones activadas. Mantén abierta esta sesion de Windows (puedes bloquear la pantalla).'
Write-Host 'Si cierras la sesion, el CRM sigue funcionando; las actualizaciones se reanudan al entrar.'
Read-Host 'Pulsa Enter para cerrar'
