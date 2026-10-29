param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia",[int]$PublicPort=3000,[int]$BackendPort=3001)
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Ejecuta como administrador en la PC servidora.'}
$active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw|ConvertFrom-Json
if($active.puerto -ne $BackendPort -and (Get-NetTCPConnection -LocalPort $BackendPort -State Listen -ErrorAction SilentlyContinue)){throw 'El puerto interno elegido ya esta ocupado. No se modifico el sistema.'}
$privatePath=Join-Path $InstallRoot 'datos/privado.json';$private=Get-Content $privatePath -Raw|ConvertFrom-Json
$oldActiveText=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw;$oldConfigText=Get-Content (Join-Path $active.path 'configuracion.json') -Raw;$oldPrivateText=Get-Content $privatePath -Raw;$changed=$false
try{
$tools=Join-Path $InstallRoot 'herramientas';$tls=Join-Path $InstallRoot 'tls';New-Item -ItemType Directory -Path $tools,$tls -Force|Out-Null
& icacls.exe $tls /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F'|Out-Null
if($LASTEXITCODE -ne 0){throw 'No se pudo proteger el certificado.'}
Copy-Item $privatePath (Join-Path $InstallRoot 'datos/privado-antes-https.json') -Force
$existing=$null;if($private.tls.thumbprint){$existing=Get-Item (Join-Path 'Cert:/LocalMachine/My' $private.tls.thumbprint) -ErrorAction SilentlyContinue}
if(-not $existing){$existing=New-SelfSignedCertificate -Type Custom -Subject 'CN=Tecnologia 10.0.0.159' -FriendlyName 'Tecnologia LAN HTTPS' -TextExtension @('2.5.29.17={text}IPAddress=10.0.0.159','2.5.29.37={text}1.3.6.1.5.5.7.3.1','2.5.29.19={text}CA=false') -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 -KeyExportPolicy Exportable -CertStoreLocation 'Cert:/LocalMachine/My' -NotAfter (Get-Date).AddYears(2)}
$bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($bytes);$rng.Dispose();$password=[Convert]::ToBase64String($bytes)
Export-PfxCertificate -Cert $existing -FilePath (Join-Path $tls 'tecnologia.pfx') -Password (ConvertTo-SecureString $password -AsPlainText -Force)|Out-Null
Export-Certificate -Cert $existing -FilePath (Join-Path $tls 'Tecnologia-LAN.cer')|Out-Null
Import-Certificate -FilePath (Join-Path $tls 'Tecnologia-LAN.cer') -CertStoreLocation 'Cert:/LocalMachine/Root'|Out-Null
$secret=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();$rng.GetBytes($secret);$rng.Dispose()
$private|Add-Member -Force NoteProperty tlsProxySecret ([Convert]::ToBase64String($secret))
$private|Add-Member -Force NoteProperty tlsEnforce $false
$private|Add-Member -Force NoteProperty tls @{port=$PublicPort;innerPort=3443;pfx=(Join-Path $tls 'tecnologia.pfx');password=$password;thumbprint=$existing.Thumbprint;expires=$existing.NotAfter.ToUniversalTime().ToString('o')}
$private.appUrl="https://10.0.0.159:$PublicPort";$private|ConvertTo-Json -Depth 8|Set-Content $privatePath -Encoding UTF8
foreach($script in @('Servidor-HTTPS.cjs','Iniciar-HTTPS.ps1')){Copy-Item (Join-Path $PSScriptRoot $script) $tools -Force}
Copy-Item (Join-Path $active.path 'runtime/node.exe') (Join-Path $tls 'node.exe') -Force
$start=Join-Path $tools 'Iniciar-HTTPS.ps1';$text=[IO.File]::ReadAllText($start).Replace("(Join-Path `$active.path 'runtime/node.exe')","(Join-Path `$InstallRoot 'tls/node.exe')");[IO.File]::WriteAllText($start,$text)
$configPath=Join-Path $active.path 'configuracion.json';$config=Get-Content $configPath -Raw|ConvertFrom-Json;$config.puerto=$BackendPort;$config|Add-Member -Force NoteProperty bindHost '127.0.0.1';$config|ConvertTo-Json -Depth 5|Set-Content $configPath -Encoding UTF8
Copy-Item $configPath (Join-Path $InstallRoot 'datos/configuracion-local.json') -Force
# Only this application's existing processes are stopped.
$changed=$true
Stop-ScheduledTask -TaskName CRM-Tecnologia
$versions=[IO.Path]::GetFullPath((Join-Path $InstallRoot 'versiones'))+'\'
Get-CimInstance Win32_Process -Filter "Name='node.exe'"|Where-Object{$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versions,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force}
$active.puerto=$BackendPort;$active|ConvertTo-Json|Set-Content (Join-Path $InstallRoot 'activo.json') -Encoding UTF8
Start-ScheduledTask -TaskName CRM-Tecnologia
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$start+'" -InstallRoot "'+$InstallRoot+'"')
$trigger=New-ScheduledTaskTrigger -AtStartup;$settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero);$runAs=New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName CRM-Tecnologia-HTTPS -Action $action -Trigger $trigger -Settings $settings -Principal $runAs -Force|Out-Null
$rule='CRM-Tecnologia-HTTPS';if(Get-NetFirewallRule -Name $rule -ErrorAction SilentlyContinue){Remove-NetFirewallRule -Name $rule}
New-NetFirewallRule -Name $rule -DisplayName 'Tecnologia HTTPS LAN' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $PublicPort -Program (Join-Path $tls 'node.exe') -RemoteAddress @('LocalSubnet','10.1.0.154/32') -Profile Domain,Private|Out-Null
Start-ScheduledTask -TaskName CRM-Tecnologia-HTTPS
Add-Type -AssemblyName System.Net.Http
$handler=New-Object Net.Http.HttpClientHandler;$handler.UseProxy=$false;$client=New-Object Net.Http.HttpClient($handler);$client.Timeout=[TimeSpan]::FromSeconds(4);$healthy=$false
try{for($attempt=0;$attempt -lt 25;$attempt++){try{$reply=$client.GetAsync($private.appUrl+'/api/local/status').GetAwaiter().GetResult();if($reply.IsSuccessStatusCode -and (($reply.Content.ReadAsStringAsync().GetAwaiter().GetResult()|ConvertFrom-Json).local)){$healthy=$true;break}}catch{};Start-Sleep -Seconds 1}}finally{$client.Dispose();$handler.Dispose()}
if(-not $healthy){throw 'HTTPS no paso la comprobacion de certificado y base local.'}
@{url=$private.appUrl;thumbprint=$existing.Thumbprint;expires=$private.tls.expires;httpCompatibility=$true}|ConvertTo-Json|Set-Content (Join-Path $InstallRoot 'https-estado.json') -Encoding UTF8
Write-Host 'HTTPS preparado. Instala el certificado publico en las PCs antes de exigir HTTPS.'

}catch{
 $reason=$_.Exception.Message
 $oldPrivateText|Set-Content $privatePath -Encoding UTF8
 if($changed){Stop-ScheduledTask -TaskName CRM-Tecnologia-HTTPS -ErrorAction SilentlyContinue;Get-CimInstance Win32_Process -Filter "Name='node.exe'"|Where-Object{$_.ExecutablePath -eq (Join-Path $tls 'node.exe')}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue};Stop-ScheduledTask -TaskName CRM-Tecnologia -ErrorAction SilentlyContinue;Get-CimInstance Win32_Process -Filter "Name='node.exe'"|Where-Object{$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versions,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object{Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue};$oldConfigText|Set-Content (Join-Path $active.path 'configuracion.json') -Encoding UTF8;$oldConfigText|Set-Content (Join-Path $InstallRoot 'datos/configuracion-local.json') -Encoding UTF8;$oldActiveText|Set-Content (Join-Path $InstallRoot 'activo.json') -Encoding UTF8;Start-ScheduledTask -TaskName CRM-Tecnologia}
 throw ('No se completo HTTPS. Se conservo el arranque anterior. '+$reason)
}
