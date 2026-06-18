$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$MobilePath = Join-Path $ProjectRoot "mobile"

Write-Host ""
Write-Host "Ejecutando smoke test Flutter..."
Write-Host ""

Push-Location $MobilePath

flutter pub get
flutter analyze

Pop-Location

Write-Host ""
Write-Host "Smoke test Flutter finalizado correctamente." -ForegroundColor Green
