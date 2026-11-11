# Arranca o eVoto (http://localhost:3000). Uso:  .\iniciar.ps1
# Liga ao SQL Server Express local (instância SQLEXPRESS, utilizador sa).
# A password do sa NÃO fica guardada no projeto: é pedida se DB_PASSWORD não estiver definida.
$env:Path = "C:\Program Files\nodejs;" + $env:Path
if (-not $env:DB_SERVER)   { $env:DB_SERVER = "localhost" }
if (-not $env:DB_INSTANCE) { $env:DB_INSTANCE = "SQLEXPRESS" }
if (-not $env:DB_USER)     { $env:DB_USER = "sa" }
if (-not $env:DB_PASSWORD) {
  $s = Read-Host "Password do utilizador sa do SQL Server" -AsSecureString
  $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
Set-Location "$PSScriptRoot\app"
node server.js
