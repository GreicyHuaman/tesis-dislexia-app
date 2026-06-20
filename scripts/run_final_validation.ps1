param(
  [string]$BaseUrl = "http://127.0.0.1:8000"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$EvidenceDir = Join-Path $ProjectRoot "docs\evidencias"

if (-not (Test-Path $EvidenceDir)) {
  New-Item -ItemType Directory -Force $EvidenceDir | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogPath = Join-Path $EvidenceDir "validacion_final_$Timestamp.txt"
$ReportPath = Join-Path $ProjectRoot "docs\reporte_validacion_final.md"

$Results = New-Object System.Collections.Generic.List[object]

function Add-ValidationResult {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Detail
  )

  $Results.Add(
    [PSCustomObject]@{
      Prueba = $Name
      Estado = $Status
      Detalle = $Detail
    }
  ) | Out-Null
}

function Write-LogSection {
  param(
    [string]$Title
  )

  $separator = "=" * 80

  Add-Content -Path $LogPath -Value ""
  Add-Content -Path $LogPath -Value $separator
  Add-Content -Path $LogPath -Value $Title
  Add-Content -Path $LogPath -Value $separator
}

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "Ejecutando: $Name" -ForegroundColor Cyan

  Write-LogSection -Title $Name

  try {
    $global:LASTEXITCODE = 0

    $output = & $Action
    $exitCode = $LASTEXITCODE

    if ($null -ne $output) {
      $output | Tee-Object -FilePath $LogPath -Append
    }

    if ($exitCode -ne 0) {
      throw "El comando termino con codigo $exitCode."
    }

    Add-ValidationResult -Name $Name -Status "OK" -Detail "Completado correctamente."
    Write-Host "OK: $Name" -ForegroundColor Green
  } catch {
    $message = $_.Exception.Message

    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "ERROR: $message"

    Add-ValidationResult -Name $Name -Status "ERROR" -Detail $message

    Write-Host "ERROR: $Name" -ForegroundColor Red
    Write-Host $message -ForegroundColor Red
  }
}

function Invoke-DockerComposeUp {
  $stdoutPath = Join-Path $env:TEMP "tesis_docker_stdout_$Timestamp.txt"
  $stderrPath = Join-Path $env:TEMP "tesis_docker_stderr_$Timestamp.txt"

  if (Test-Path $stdoutPath) {
    Remove-Item $stdoutPath -Force
  }

  if (Test-Path $stderrPath) {
    Remove-Item $stderrPath -Force
  }

  $process = Start-Process `
    -FilePath "docker" `
    -ArgumentList @("compose", "-f", "infra\docker-compose.yml", "up", "-d") `
    -WorkingDirectory $ProjectRoot `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

  $stdout = ""
  $stderr = ""

  if (Test-Path $stdoutPath) {
    $stdout = Get-Content $stdoutPath -Raw
  }

  if (Test-Path $stderrPath) {
    $stderr = Get-Content $stderrPath -Raw
  }

  if ($stdout.Trim()) {
    $stdout.Trim()
  }

  if ($stderr.Trim()) {
    $stderr.Trim()
  }

  if ($process.ExitCode -ne 0) {
    throw "docker compose up -d fallo con codigo $($process.ExitCode). $stderr"
  }

  $global:LASTEXITCODE = 0
}

function Write-FinalReport {
  $now = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

  $lines = New-Object System.Collections.Generic.List[string]

  $lines.Add("# Reporte de validacion final") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("Fecha de ejecucion: $now") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("Archivo de log: docs/evidencias/$(Split-Path -Leaf $LogPath)") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("## Resultado general") | Out-Null
  $lines.Add("") | Out-Null

  $errorCount = @($Results | Where-Object { $_.Estado -eq "ERROR" }).Count
  $okCount = @($Results | Where-Object { $_.Estado -eq "OK" }).Count

  $lines.Add("| Indicador | Valor |") | Out-Null
  $lines.Add("|---|---:|") | Out-Null
  $lines.Add("| Pruebas OK | $okCount |") | Out-Null
  $lines.Add("| Pruebas con error | $errorCount |") | Out-Null
  $lines.Add("") | Out-Null

  $lines.Add("## Detalle de pruebas") | Out-Null
  $lines.Add("") | Out-Null
  $lines.Add("| Prueba | Estado | Detalle |") | Out-Null
  $lines.Add("|---|---|---|") | Out-Null

  foreach ($result in $Results) {
    $detail = $result.Detalle.Replace("|", "/")
    $lines.Add("| $($result.Prueba) | $($result.Estado) | $detail |") | Out-Null
  }

  $lines.Add("") | Out-Null
  $lines.Add("## Interpretacion") | Out-Null
  $lines.Add("") | Out-Null

  if ($errorCount -eq 0) {
    $lines.Add("La validacion final se ejecuto correctamente. No se detectaron fallos en los pasos automatizados.") | Out-Null
  } else {
    $lines.Add("La validacion final detecto errores. Revisar el archivo de log asociado para corregirlos.") | Out-Null
  }

  $lines.Add("") | Out-Null
  $lines.Add("El sistema mantiene su alcance como prototipo de tamizaje educativo y no constituye diagnostico clinico.") | Out-Null

  Set-Content -Encoding UTF8 -Path $ReportPath -Value $lines
}

Push-Location $ProjectRoot

try {
  Set-Content -Encoding UTF8 -Path $LogPath -Value "Validacion final iniciada: $(Get-Date)"
  Add-Content -Path $LogPath -Value "Proyecto: $ProjectRoot"
  Add-Content -Path $LogPath -Value "Backend: $BaseUrl"

  Run-Step -Name "Verificar backend preparado" -Action {
    "El levantamiento de Docker se omite en la validacion final automatica."
    "El backend se valida en el siguiente paso mediante /health."
    $global:LASTEXITCODE = 0
  }

  Run-Step -Name "Health check backend" -Action {
    Invoke-RestMethod `
      -Uri "$BaseUrl/health" `
      -TimeoutSec 10 | ConvertTo-Json -Depth 5
  }

  Run-Step -Name "Smoke test backend" -Action {
    & .\scripts\smoke_test_backend.ps1
  }

  Run-Step -Name "Smoke test Flutter" -Action {
    & .\scripts\smoke_test_flutter.ps1
  }

  Run-Step -Name "Exportar dataset ML" -Action {
    & .\scripts\export_ml_dataset.ps1 -BaseUrl $BaseUrl
  }

  Run-Step -Name "Validar modelos ML" -Action {
    python .\ml\validate_models.py `
      --dataset data\processed\ml_dataset.csv `
      --output-dir data\processed\ml_validation `
      --models-dir ml\models
  }

  Run-Step -Name "Generar documento de resultados ML" -Action {
    python .\scripts\generate_ml_validation_docs.py
  }

  Run-Step -Name "Generar evidencia experimental del dataset" -Action {
    python .\scripts\generate_dataset_evidence.py
  }

  Run-Step -Name "Estado Git" -Action {
    git status --short
  }

  Write-FinalReport

  Write-Host ""
  Write-Host "Validacion final terminada." -ForegroundColor Green
  Write-Host "Log: $LogPath"
  Write-Host "Reporte: $ReportPath"
  Write-Host ""

  $Results | Format-Table -AutoSize
} finally {
  Pop-Location
}

