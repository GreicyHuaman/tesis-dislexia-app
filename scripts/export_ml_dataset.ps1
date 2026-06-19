param(
  [string]$BaseUrl = "http://127.0.0.1:8000",
  [string]$Email = "directora@demo.com",
  [string]$Password = "123456",
  [string]$OutputPath = "data\processed\ml_dataset.csv"
)

$ErrorActionPreference = "Stop"

$BaseUrl = $BaseUrl.TrimEnd("/")

Write-Host ""
Write-Host "Exportando dataset ML desde $BaseUrl..." -ForegroundColor Cyan
Write-Host ""

$body = @{
  email = $Email
  password = $Password
} | ConvertTo-Json

$login = Invoke-RestMethod `
  -Method Post `
  -Uri "$BaseUrl/api/v1/auth/login" `
  -ContentType "application/json" `
  -Body $body `
  -TimeoutSec 15

if (-not $login.access_token) {
  throw "No se recibio access_token desde el backend."
}

$headers = @{
  Authorization = "Bearer $($login.access_token)"
}

Write-Host "Login correcto: $Email" -ForegroundColor Green

$openapi = Invoke-RestMethod `
  -Uri "$BaseUrl/openapi.json" `
  -TimeoutSec 15

$paths = @(
  $openapi.paths.PSObject.Properties.Name |
    Where-Object { $_ -match "dataset|ml|csv" } |
    Sort-Object
)

Write-Host ""
Write-Host "Rutas detectadas relacionadas con ML/dataset/csv:" -ForegroundColor Cyan
$paths | ForEach-Object {
  Write-Host " - $_"
}

$csvPath = $paths |
  Where-Object { $_ -match "dataset" -and $_ -match "\.csv$" } |
  Select-Object -First 1

if (-not $csvPath) {
  $csvPath = $paths |
    Where-Object { $_ -match "csv" } |
    Select-Object -First 1
}

if (-not $csvPath) {
  throw "No se encontro endpoint CSV del dataset ML en OpenAPI. Revisa si app.include_router(ml_dataset_router) esta activo en backend/app/main.py."
}

Write-Host ""
Write-Host "Usando endpoint CSV:" -ForegroundColor Green
Write-Host "$BaseUrl$csvPath"

$outputDirectory = Split-Path -Parent $OutputPath

if (-not (Test-Path $outputDirectory)) {
  New-Item -ItemType Directory -Force $outputDirectory | Out-Null
}

Invoke-WebRequest `
  -Method Get `
  -Uri "$BaseUrl$csvPath" `
  -Headers $headers `
  -OutFile $OutputPath `
  -TimeoutSec 30 `
  -UseBasicParsing

Write-Host ""
Write-Host "Dataset exportado correctamente:" -ForegroundColor Green
Write-Host $OutputPath
Write-Host ""

Write-Host "Primeras lineas del dataset:" -ForegroundColor Cyan
Get-Content $OutputPath -TotalCount 5
