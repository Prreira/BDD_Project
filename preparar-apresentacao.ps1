# Prepara o eVoto para a apresentação:
#   1) verifica Node.js e o serviço do SQL Server;  2) instala dependências se faltarem;
#   3) recria a base de dados com datas atuais;      4) arranca a aplicação em http://localhost:3000
# Uso:  .\preparar-apresentacao.ps1            (a password do sa vem de $env:DB_PASSWORD ou é pedida)
$ErrorActionPreference = "Stop"
$env:Path = "C:\Program Files\nodejs;" + $env:Path
if (-not $env:DB_SERVER)   { $env:DB_SERVER = "localhost" }
if (-not $env:DB_INSTANCE) { $env:DB_INSTANCE = "SQLEXPRESS" }
if (-not $env:DB_USER)     { $env:DB_USER = "sa" }
if (-not $env:DB_PASSWORD) {
  $s = Read-Host "Password do utilizador sa do SQL Server" -AsSecureString
  $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}

Write-Host "1/4 A verificar requisitos..." -ForegroundColor Cyan
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "Node.js não encontrado. Instale o Node.js 18 ou superior." }
Write-Host ("   Node.js " + (node --version))
$svc = Get-Service | Where-Object { $_.Name -like 'MSSQL$*' -or $_.Name -eq 'MSSQLSERVER' } | Select-Object -First 1
if (-not $svc) { throw "Serviço do SQL Server não encontrado." }
if ($svc.Status -ne 'Running') { Write-Host "   A iniciar $($svc.Name)..."; Start-Service $svc.Name }
Write-Host "   SQL Server: $($svc.Name) ($((Get-Service $svc.Name).Status))"

Set-Location "$PSScriptRoot\app"
Write-Host "2/4 Dependências..." -ForegroundColor Cyan
if (-not (Test-Path node_modules/chart.js)) { npm install --no-audit --no-fund }

Write-Host "3/4 A recriar a base de dados com dados de demonstração..." -ForegroundColor Cyan
node setup.js
if ($LASTEXITCODE -ne 0) { throw "O setup falhou. Verifique a password e a ligação ao SQL Server." }

Write-Host "4/4 A arrancar o servidor em http://localhost:3000 (Ctrl+C para parar)" -ForegroundColor Green
Start-Process "http://localhost:3000"
node server.js
