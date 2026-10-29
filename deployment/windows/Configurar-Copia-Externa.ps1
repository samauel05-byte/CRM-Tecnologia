param([Parameter(Mandatory=$true)][string]$Destino,[string]$InstallRoot="$env:ProgramData\CRM-Tecnologia")
$ErrorActionPreference='Stop'
$target=[IO.Path]::GetFullPath($Destino);if(-not(Test-Path -LiteralPath $target -PathType Container)){throw 'La carpeta de destino no existe. Crea primero la carpeta en el disco externo o equipo de respaldo.'}
if($target -notlike '\\*'){$drive=[IO.Path]::GetPathRoot($target).Substring(0,1);$destinationDisk=Get-Partition -DriveLetter $drive|Get-Disk;$sourceDisk=Get-Partition -DriveLetter ([IO.Path]::GetPathRoot($InstallRoot).Substring(0,1))|Get-Disk;if($destinationDisk.Number -eq $sourceDisk.Number){throw 'El destino esta en el mismo disco fisico que el CRM. Elige un disco externo o un equipo distinto.'}}
$probe=Join-Path $target ('tecnologia-prueba-'+[Guid]::NewGuid().ToString('N'));[IO.File]::WriteAllText($probe,'Prueba de acceso');Remove-Item -LiteralPath $probe
$privatePath=Join-Path $InstallRoot 'datos/privado.json';$private=Get-Content $privatePath -Raw|ConvertFrom-Json;$private|Add-Member -Force NoteProperty backupDestination $target;$private|ConvertTo-Json -Depth 8|Set-Content $privatePath -Encoding UTF8
Write-Host 'Destino externo configurado. La siguiente copia comprobará el acceso de la cuenta del servicio y su restauracion.'
