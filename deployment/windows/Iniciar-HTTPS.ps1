param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
$active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw|ConvertFrom-Json
& (Join-Path $active.path 'runtime/node.exe') (Join-Path $InstallRoot 'herramientas/Servidor-HTTPS.cjs') $InstallRoot
