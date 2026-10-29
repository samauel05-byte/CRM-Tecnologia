param([Parameter(Mandatory=$true)][string]$Copia,[Parameter(Mandatory=$true)][string]$Clave,[Parameter(Mandatory=$true)][string]$Destino,[string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
$target=[IO.Path]::GetFullPath($Destino);if($target -eq [IO.Path]::GetPathRoot($target)){throw 'Elige una carpeta nueva dentro del disco.'}
if((Test-Path -LiteralPath $target) -and (Get-ChildItem -LiteralPath $target -Force|Select-Object -First 1)){throw 'El destino debe estar vacio. No se reemplazaron datos.'}
New-Item -ItemType Directory -Path $target -Force|Out-Null
& icacls.exe $target /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F'|Out-Null
if($LASTEXITCODE -ne 0){throw 'No se pudo proteger la carpeta restaurada.'}
$active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw|ConvertFrom-Json
& (Join-Path $active.path 'runtime/node.exe') (Join-Path $PSScriptRoot 'Restaurar-Copia.cjs') $Copia $Clave $target
if($LASTEXITCODE -ne 0){throw 'La copia no paso la restauracion.'}
Write-Host 'Restauracion comprobada en una carpeta separada. El sistema activo no se ha modificado.'
