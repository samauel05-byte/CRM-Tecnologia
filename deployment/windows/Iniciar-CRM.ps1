$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$config=Get-Content -LiteralPath (Join-Path $root 'configuracion.json') -Raw | ConvertFrom-Json
$env:NEXT_PUBLIC_SUPABASE_URL=$config.supabaseUrl
$env:NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$config.supabasePublishableKey
$env:NODE_ENV='production'
$env:HOSTNAME='0.0.0.0'
$env:PORT=[string]$config.puerto
$logDirectory=Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$serverFile=Join-Path $root 'app/server.js'
$serverArgument='"'+$serverFile+'"'
Start-Process -FilePath (Join-Path $root 'runtime/node.exe') -ArgumentList $serverArgument -WorkingDirectory (Join-Path $root 'app') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDirectory 'crm.log') -RedirectStandardError (Join-Path $logDirectory 'errores.log') -Wait
