param([string]$Destino=(Join-Path (Get-Location) 'work/paquete-windows'),[string]$Commit=$env:GITHUB_SHA)
$ErrorActionPreference='Stop'
if(-not(Test-Path '.next/standalone/server.js')){throw 'Primero compila el CRM.'}
if(-not $Commit){throw 'Indica el commit que se incluye en el paquete.'}
if((Test-Path -LiteralPath $Destino) -and (Get-ChildItem -LiteralPath $Destino -Force|Select-Object -First 1)){throw 'Usa una carpeta de paquete nueva y vacia para evitar mezclar versiones.'}
$manifest=Get-Content '.next/standalone/.next/server/app-paths-manifest.json' -Raw|ConvertFrom-Json
if(-not $manifest.'/api/local/status/route' -or -not $manifest.'/api/operations/route'){throw 'La compilacion no incluye las rutas locales actuales.'}
New-Item -ItemType Directory -Path $Destino -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Destino 'app') -Force | Out-Null
Copy-Item .next/standalone/* (Join-Path $Destino 'app') -Recurse -Force
Copy-Item public (Join-Path $Destino 'app') -Recurse -Force
Copy-Item .next/static (Join-Path $Destino 'app/.next') -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $Destino 'runtime') -Force | Out-Null
$nodePath=(Get-Command node.exe -ErrorAction Stop).Source
Copy-Item -LiteralPath $nodePath -Destination (Join-Path $Destino 'runtime/node.exe')
Invoke-WebRequest 'https://raw.githubusercontent.com/nodejs/node/v24.22.1/LICENSE' -OutFile (Join-Path $Destino 'runtime/LICENSE.txt') -UseBasicParsing
Copy-Item deployment/windows/* $Destino -Force
Copy-Item deployment/windows/configuracion-publica.json (Join-Path $Destino 'configuracion.json') -Force
@{commit=$Commit;repository='samauel05-byte/CRM-Tecnologia';createdAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $Destino 'version.json') -Encoding UTF8
if(Get-ChildItem $Destino -Force -Recurse -Filter '.env*'){throw 'El paquete contiene un archivo de entorno.'}
