param([string]$InstallRoot="$env:ProgramData\CRM-Tecnologia",[string]$Red)
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Ejecuta AUTORIZAR-VLAN.cmd como administrador en la PC servidora.'}
if(-not $Red){$Red=Read-Host 'Red de la VLAN autorizada en formato CIDR, por ejemplo 10.0.20.0/24'}
$parts=$Red.Split('/');$ip=$null;$prefix=0
if($parts.Count -ne 2 -or -not [Net.IPAddress]::TryParse($parts[0],[ref]$ip) -or $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or -not [int]::TryParse($parts[1],[ref]$prefix) -or $prefix -lt 8 -or $prefix -gt 32){throw 'Indica una subred IPv4 privada valida con su prefijo.'}
$bytes=$ip.GetAddressBytes();$private=$bytes[0] -eq 10 -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31 -and $prefix -ge 12) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168 -and $prefix -ge 16)
if(-not $private){throw 'Solo se admiten las redes privadas de la oficina.'}
$active=Get-Content (Join-Path $InstallRoot 'activo.json') -Raw | ConvertFrom-Json
$path=Join-Path $active.path 'configuracion.json';$config=Get-Content $path -Raw | ConvertFrom-Json
$allowed=@('LocalSubnet')+@($config.allowedSubnets)+@($Red) | Where-Object {$_} | Select-Object -Unique
Set-NetFirewallRule -Name 'CRM-Tecnologia-LAN' -RemoteAddress $allowed
$config | Add-Member -NotePropertyName allowedSubnets -NotePropertyValue @($allowed) -Force
$config | ConvertTo-Json -Depth 4 | Set-Content $path -Encoding UTF8
Write-Host "VLAN $Red autorizada en el firewall de esta PC para el CRM."
Write-Host "El router debe permitir desde esa VLAN hacia 10.0.0.159, TCP puerto $($active.puerto). No requiere publicar el CRM en Internet."
Read-Host 'Pulsa Enter para cerrar'
