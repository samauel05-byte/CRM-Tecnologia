param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia",[switch]$Mostrar)
$ErrorActionPreference='Stop'
$mutex=New-Object Threading.Mutex($false,'Global\CRM-Tecnologia-Actualizacion')
if(-not $mutex.WaitOne(0)){$mutex.Dispose();exit 0}
$log=Join-Path $InstallRoot 'actualizaciones.log'
function Log([string]$Text){Add-Content -LiteralPath $log -Value ((Get-Date -Format s)+' '+$Text);if($Mostrar){Write-Host $Text}}
function GhJson([string[]]$Arguments){$result=& $script:gh @Arguments 2>$null;if($LASTEXITCODE -ne 0){throw 'No se pudo consultar GitHub. Revisa tu inicio de sesion en GitHub CLI.'};return ($result -join "`n" | ConvertFrom-Json)}
try {
 $settings=Get-Content (Join-Path $InstallRoot 'actualizador.json') -Raw | ConvertFrom-Json
 $script:gh=$settings.gh
 $repo='samauel05-byte/CRM-Tecnologia'
 $head=GhJson @('api',"repos/$repo/git/ref/heads/main")
 $active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw | ConvertFrom-Json
 if($head.object.sha -eq $active.commit){Log 'Ya esta actualizado.';exit 0}
 $runs=GhJson @('api',"repos/$repo/actions/workflows/crm-windows.yml/runs?branch=main&status=success&per_page=1")
 $run=@($runs.workflow_runs) | Select-Object -First 1
 if(-not $run -or $run.head_sha -ne $head.object.sha){Log 'Esperando que GitHub termine de comprobar la nueva version.';exit 0}
 if($run.head_branch -ne 'main' -or $run.head_repository.full_name -ne $repo -or $run.event -notin @('push','workflow_dispatch')){throw 'Origen de paquete no permitido.'}
 $download=Join-Path $InstallRoot ('descargas\'+[Guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Path $download -Force | Out-Null
 & $script:gh run download ([string]$run.id) --repo $repo --name crm-windows --dir $download 2>$null
 if($LASTEXITCODE -ne 0){throw 'No se pudo descargar la nueva version.'}
 $package=Join-Path $download 'paquete'
 Expand-Archive -LiteralPath (Join-Path $download 'CRM-Tecnologia-Windows.zip') -DestinationPath $package
 $version=Get-Content (Join-Path $package 'version.json') -Raw | ConvertFrom-Json
 if($version.commit -ne $run.head_sha -or $version.repository -ne $repo){throw 'La version descargada no coincide con GitHub.'}
 $oldXml=Export-ScheduledTask -TaskName 'CRM-Tecnologia'
 Log ('Instalando '+$version.commit)
 try {
  & (Join-Path $package 'Instalar-CRM.ps1') -InstallRoot $InstallRoot -Puerto $active.puerto -SourceConfigPath (Join-Path $active.path 'configuracion.json') -NoPause
  Log 'Actualizacion instalada y comprobada.'
 } catch {
  Stop-ScheduledTask -TaskName 'CRM-Tecnologia' -ErrorAction SilentlyContinue
  $failed=Get-ScheduledTask -TaskName 'CRM-Tecnologia'
  # Only stop node binaries inside this CRM installation.
  $versionsRoot=[IO.Path]::GetFullPath((Join-Path $InstallRoot 'versiones'))+'\'
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($versionsRoot,[StringComparison]::OrdinalIgnoreCase)} | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
  Register-ScheduledTask -TaskName 'CRM-Tecnologia' -Xml $oldXml -Force | Out-Null
  Get-NetFirewallRule -Name 'CRM-Tecnologia-LAN' | Get-NetFirewallApplicationFilter | Set-NetFirewallApplicationFilter -Program (Join-Path $active.path 'runtime/node.exe')
  $active | ConvertTo-Json | Set-Content (Join-Path $InstallRoot 'activo.json') -Encoding UTF8
  Start-ScheduledTask -TaskName 'CRM-Tecnologia'
  throw 'La nueva version fallo. Se ha restaurado el arranque de la version anterior.'
 }
} catch {Log $_.Exception.Message;if($Mostrar){exit 1}}
finally {$mutex.ReleaseMutex();$mutex.Dispose()}
