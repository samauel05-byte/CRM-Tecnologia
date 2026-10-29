$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$config=Get-Content -LiteralPath (Join-Path $root 'configuracion.json') -Raw | ConvertFrom-Json
if($config.storage -eq 'local'){
 $env:CRM_STORAGE='local'
 $env:CRM_DATA_DIR=$config.dataDirectory
 $env:CRM_PRIVATE_CONFIG=Join-Path $config.dataDirectory 'privado.json'
 $private=Get-Content -LiteralPath $env:CRM_PRIVATE_CONFIG -Raw|ConvertFrom-Json
 $env:CRM_PUBLIC_URL=$private.appUrl
 $env:CRM_PROXY_SECRET=$private.tlsProxySecret
 $env:CRM_HTTPS_ENFORCE=if($private.tlsEnforce){'1'}else{'0'}
}else{$env:CRM_STORAGE='supabase'}
$env:NEXT_PUBLIC_SUPABASE_URL=$config.supabaseUrl
$env:NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$config.supabasePublishableKey
$env:NODE_ENV='production'
$env:HOSTNAME=if($config.bindHost){$config.bindHost}else{'0.0.0.0'}
$env:PORT=[string]$config.puerto
$logDirectory=Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$serverFile=Join-Path $root 'app/server.js'
$serverArgument='"'+$serverFile+'"'
Start-Process -FilePath (Join-Path $root 'runtime/node.exe') -ArgumentList $serverArgument -WorkingDirectory (Join-Path $root 'app') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDirectory 'crm.log') -RedirectStandardError (Join-Path $logDirectory 'errores.log') -Wait
