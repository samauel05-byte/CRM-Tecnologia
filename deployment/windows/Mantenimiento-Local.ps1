param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
try{
 $active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw | ConvertFrom-Json
 $config=Get-Content (Join-Path $active.path 'configuracion.json') -Raw | ConvertFrom-Json
 if($config.storage -ne 'local'){exit 0}
 $private=Get-Content (Join-Path $config.dataDirectory 'privado.json') -Raw | ConvertFrom-Json
 Invoke-WebRequest -Uri "http://127.0.0.1:$($active.puerto)/api/local/maintenance" -Method POST -Headers @{Authorization=('Bearer '+$private.maintenanceSecret)} -UseBasicParsing -TimeoutSec 280 | Out-Null
}catch{Add-Content (Join-Path $InstallRoot 'mantenimiento.log') ((Get-Date -Format s)+' No se completo el mantenimiento local.');exit 1}
