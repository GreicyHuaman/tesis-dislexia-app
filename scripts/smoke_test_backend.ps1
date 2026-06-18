param(
  [switch]$CreateTestEvaluation
)

$ErrorActionPreference = "Stop"

$BaseUrl = "http://127.0.0.1:8000"
$Results = @()

function Add-Result {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Details = ""
  )

  $script:Results += [PSCustomObject]@{
    Prueba = $Name
    Estado = $Status
    Detalle = $Details
  }
}

function Test-Get {
  param(
    [string]$Name,
    [string]$Path,
    [bool]$Required = $true
  )

  try {
    $uri = "$BaseUrl$Path"
    $response = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 15

    if ($null -eq $response) {
      Add-Result -Name $Name -Status "OK" -Details "Respuesta vacia valida"
    } else {
      Add-Result -Name $Name -Status "OK" -Details "Endpoint responde"
    }
  } catch {
    if ($Required) {
      Add-Result -Name $Name -Status "ERROR" -Details $_.Exception.Message
    } else {
      Add-Result -Name $Name -Status "ADVERTENCIA" -Details $_.Exception.Message
    }
  }
}

function Test-Csv {
  param(
    [string]$Name,
    [string]$Path
  )

  try {
    $uri = "$BaseUrl$Path"
    $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $uri -TimeoutSec 15

    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
      Add-Result -Name $Name -Status "OK" -Details "CSV responde con HTTP $($response.StatusCode)"
    } else {
      Add-Result -Name $Name -Status "ERROR" -Details "HTTP $($response.StatusCode)"
    }
  } catch {
    Add-Result -Name $Name -Status "ERROR" -Details $_.Exception.Message
  }
}

function Test-CreateEvaluation {
  try {
    $sessionId = [guid]::NewGuid().ToString()
    $now = (Get-Date).ToUniversalTime().ToString("o")

    $payload = @{
      sessions = @(
        @{
          local_session_id = $sessionId
          estudiante_id = 1
          tipo_prueba = "LECTURA"
          fecha_inicio = $now
          fecha_fin = $now
          total_items = 3
          aciertos_primer_intento = 2
          taps_erroneos_totales = 1
          tiempo_promedio_ms = 3100
          sync_status = "COMPLETED_PENDING_SYNC"
        }
      )
      details = @(
        @{
          local_detail_id = [guid]::NewGuid().ToString()
          local_session_id = $sessionId
          stimulus_id = "smoke_001"
          texto = "casa"
          tipo_prueba = "LECTURA"
          tiempo_respuesta_ms = 2100
          duracion_drag_drop_ms = $null
          taps_erroneos = 0
          tipo_error = $null
          complejidad_estimulo = "BAJA"
          acierto = $true
        },
        @{
          local_detail_id = [guid]::NewGuid().ToString()
          local_session_id = $sessionId
          stimulus_id = "smoke_002"
          texto = "plato"
          tipo_prueba = "LECTURA"
          tiempo_respuesta_ms = 3300
          duracion_drag_drop_ms = $null
          taps_erroneos = 1
          tipo_error = "TAP_INCORRECTO"
          complejidad_estimulo = "MEDIA"
          acierto = $false
        },
        @{
          local_detail_id = [guid]::NewGuid().ToString()
          local_session_id = $sessionId
          stimulus_id = "smoke_003"
          texto = "camino"
          tipo_prueba = "LECTURA"
          tiempo_respuesta_ms = 3900
          duracion_drag_drop_ms = $null
          taps_erroneos = 0
          tipo_error = $null
          complejidad_estimulo = "MEDIA"
          acierto = $true
        }
      )
    }

    $body = $payload | ConvertTo-Json -Depth 8

    $response = Invoke-RestMethod `
      -Method Post `
      -Uri "$BaseUrl/api/v1/evaluaciones/sync" `
      -ContentType "application/json" `
      -Body $body `
      -TimeoutSec 30

    Add-Result `
      -Name "POST sync evaluacion demo" `
      -Status "OK" `
      -Details "Insertadas: $($response.evaluations_inserted), detalles: $($response.details_inserted)"
  } catch {
    Add-Result `
      -Name "POST sync evaluacion demo" `
      -Status "ERROR" `
      -Details $_.Exception.Message
  }
}

Write-Host ""
Write-Host "Ejecutando smoke test backend en $BaseUrl"
Write-Host ""

Test-Get -Name "Health check" -Path "/health"
Test-Get -Name "Estado modelo ML" -Path "/api/v1/evaluaciones/model-status"
Test-Get -Name "Debug evaluaciones" -Path "/api/v1/evaluaciones/debug"
Test-Get -Name "Lista estudiantes" -Path "/api/v1/estudiantes"
Test-Get -Name "Padrón offline" -Path "/api/v1/estudiantes/offline-cache"
Test-Get -Name "Reportes evaluaciones" -Path "/api/v1/reportes/evaluaciones"
Test-Get -Name "Resumen semáforo" -Path "/api/v1/reportes/resumen-semaforo"
Test-Get -Name "Filtro reportes FONOLOGIA" -Path "/api/v1/reportes/evaluaciones?tipo_prueba=FONOLOGIA"
Test-Get -Name "Dataset ML JSON" -Path "/api/v1/ml/dataset"
Test-Csv -Name "Dataset ML CSV" -Path "/api/v1/ml/dataset.csv"
Test-Csv -Name "Reporte evaluaciones CSV" -Path "/api/v1/reportes/evaluaciones.csv"

Test-Get `
  -Name "Perfil estudiante ID 1" `
  -Path "/api/v1/reportes/estudiantes/1/perfil-riesgo" `
  -Required $false

if ($CreateTestEvaluation) {
  Test-CreateEvaluation
}

Write-Host ""
$Results | Format-Table -AutoSize

$errors = $Results | Where-Object { $_.Estado -eq "ERROR" }

if ($errors.Count -gt 0) {
  Write-Host ""
  Write-Host "Smoke test backend finalizado con errores." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Smoke test backend finalizado correctamente." -ForegroundColor Green
exit 0

