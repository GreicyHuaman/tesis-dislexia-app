import csv
import io
from math import sqrt

from fastapi import APIRouter, Depends
from fastapi.responses import Response
from sqlmodel import Session, select

from app.core.security import require_roles
from app.db.session import get_session
from app.models.evaluation import DetalleEvaluacion, Evaluacion
from app.models.student import Estudiante
from app.schemas.ml_dataset_schema import MlDatasetItem

router = APIRouter(
    prefix="/api/v1/ml",
    tags=["ml"],
)


def _safe_divide(numerator: int | float, denominator: int | float) -> float:
    if denominator == 0:
        return 0.0

    return round(numerator / denominator, 4)


def _std(values: list[int]) -> float | None:
    if not values:
        return None

    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)

    return round(sqrt(variance), 2)


def _tipo_prueba_flags(tipo_prueba: str | None) -> tuple[int, int, int]:
    normalized = (tipo_prueba or "").upper()

    tipo_prueba_lectura = 1 if normalized == "LECTURA" else 0
    tipo_prueba_fonologia = 1 if normalized == "FONOLOGIA" else 0
    tipo_prueba_otro = 1 if normalized not in {"LECTURA", "FONOLOGIA"} else 0

    return tipo_prueba_lectura, tipo_prueba_fonologia, tipo_prueba_otro


def _tipo_estimulo_fonologico(detalle: DetalleEvaluacion) -> str:
    tipo_prueba = (detalle.tipo_prueba or "").upper()

    if tipo_prueba != "FONOLOGIA":
        return "NO_APLICA"

    texto = (detalle.texto or "").strip()
    first_part = texto.split("|", 1)[0].strip().upper()

    if first_part == "PSEUDOPALABRA":
        return "PSEUDOPALABRA"

    if first_part == "PALABRA_REAL":
        return "PALABRA_REAL"

    # Compatibilidad con evaluaciones fonologicas anteriores,
    # cuando texto era "palabra|silaba".
    return "PALABRA_REAL"


def _average(values: list[int]) -> int:
    if not values:
        return 0

    return round(sum(values) / len(values))


def _build_dataset(session: Session) -> list[MlDatasetItem]:
    statement = (
        select(Evaluacion, Estudiante)
        .join(
            Estudiante,
            Evaluacion.estudiante_id == Estudiante.id,
            isouter=True,
        )
        .order_by(Evaluacion.fecha_evaluacion.desc())
    )

    rows = session.exec(statement).all()

    dataset: list[MlDatasetItem] = []

    for evaluacion, estudiante in rows:
        if evaluacion.id is None:
            continue

        detalles = session.exec(
            select(DetalleEvaluacion).where(
                DetalleEvaluacion.evaluacion_id == evaluacion.id,
            )
        ).all()

        total_items = evaluacion.total_items or len(detalles)

        aciertos_primer_intento = (
            evaluacion.aciertos_primer_intento
            if evaluacion.aciertos_primer_intento is not None
            else sum(1 for detalle in detalles if detalle.acierto)
        )

        errores_primer_intento = max(
            total_items - aciertos_primer_intento,
            0,
        )

        taps_erroneos_totales = (
            evaluacion.taps_erroneos_totales
            if evaluacion.taps_erroneos_totales is not None
            else sum(detalle.taps_erroneos for detalle in detalles)
        )

        tiempos = [
            detalle.tiempo_respuesta_ms
            for detalle in detalles
            if detalle.tiempo_respuesta_ms is not None
        ]

        tiempo_promedio_ms = (
            evaluacion.tiempo_promedio_ms
            if evaluacion.tiempo_promedio_ms is not None
            else round(sum(tiempos) / len(tiempos)) if tiempos else 0
        )

        drag_durations = [
            detalle.duracion_drag_drop_ms
            for detalle in detalles
            if detalle.duracion_drag_drop_ms is not None
        ]

        items_drag_drop = len(drag_durations)

        tiempo_promedio_drag_drop_ms = _average(drag_durations)

        errores_drag_drop = sum(
            detalle.taps_erroneos
            for detalle in detalles
            if detalle.duracion_drag_drop_ms is not None
            or (detalle.tipo_error or "").upper().startswith("DRAG")
        )

        palabra_real_times: list[int] = []
        pseudopalabra_times: list[int] = []

        items_palabra_real = 0
        items_pseudopalabra = 0
        errores_palabra_real = 0
        errores_pseudopalabra = 0

        for detalle in detalles:
            tipo_estimulo = _tipo_estimulo_fonologico(detalle)

            if tipo_estimulo == "PALABRA_REAL":
                items_palabra_real += 1
                palabra_real_times.append(detalle.tiempo_respuesta_ms)

                if not detalle.acierto:
                    errores_palabra_real += 1

            elif tipo_estimulo == "PSEUDOPALABRA":
                items_pseudopalabra += 1
                pseudopalabra_times.append(detalle.tiempo_respuesta_ms)

                if not detalle.acierto:
                    errores_pseudopalabra += 1

        complexity_totals = {
            "BAJA": 0,
            "MEDIA": 0,
            "ALTA": 0,
            "SIN_COMPLEJIDAD": 0,
        }

        complexity_errors = {
            "BAJA": 0,
            "MEDIA": 0,
            "ALTA": 0,
            "SIN_COMPLEJIDAD": 0,
        }

        for detalle in detalles:
            complexity = (
                detalle.complejidad_estimulo or "SIN_COMPLEJIDAD"
            ).upper()

            if complexity not in complexity_totals:
                complexity = "SIN_COMPLEJIDAD"

            complexity_totals[complexity] += 1

            if not detalle.acierto:
                complexity_errors[complexity] += 1

        (
            tipo_prueba_lectura,
            tipo_prueba_fonologia,
            tipo_prueba_otro,
        ) = _tipo_prueba_flags(evaluacion.tipo_prueba)

        dataset.append(
            MlDatasetItem(
                evaluacion_id=evaluacion.id,
                estudiante_id=evaluacion.estudiante_id,
                seccion_id=estudiante.seccion_id if estudiante else None,
                tipo_prueba=evaluacion.tipo_prueba,
                tipo_prueba_lectura=tipo_prueba_lectura,
                tipo_prueba_fonologia=tipo_prueba_fonologia,
                tipo_prueba_otro=tipo_prueba_otro,
                total_items=total_items,
                aciertos_primer_intento=aciertos_primer_intento,
                errores_primer_intento=errores_primer_intento,
                error_rate=_safe_divide(errores_primer_intento, total_items),
                taps_erroneos_totales=taps_erroneos_totales,
                taps_rate=_safe_divide(taps_erroneos_totales, total_items),
                tiempo_promedio_ms=tiempo_promedio_ms,
                tiempo_min_ms=min(tiempos) if tiempos else None,
                tiempo_max_ms=max(tiempos) if tiempos else None,
                tiempo_std_ms=_std(tiempos),
                items_drag_drop=items_drag_drop,
                drag_drop_rate=_safe_divide(items_drag_drop, total_items),
                tiempo_promedio_drag_drop_ms=tiempo_promedio_drag_drop_ms,
                errores_drag_drop=errores_drag_drop,
                items_palabra_real=items_palabra_real,
                items_pseudopalabra=items_pseudopalabra,
                pseudopalabra_rate=_safe_divide(items_pseudopalabra, total_items),
                errores_palabra_real=errores_palabra_real,
                errores_pseudopalabra=errores_pseudopalabra,
                tiempo_promedio_palabra_real_ms=_average(palabra_real_times),
                tiempo_promedio_pseudopalabra_ms=_average(pseudopalabra_times),
                total_baja=complexity_totals["BAJA"],
                total_media=complexity_totals["MEDIA"],
                total_alta=complexity_totals["ALTA"],
                total_sin_complejidad=complexity_totals["SIN_COMPLEJIDAD"],
                errores_baja=complexity_errors["BAJA"],
                errores_media=complexity_errors["MEDIA"],
                errores_alta=complexity_errors["ALTA"],
                errores_sin_complejidad=complexity_errors["SIN_COMPLEJIDAD"],
                porcentaje_riesgo=evaluacion.porcentaje_riesgo,
                semaforo=evaluacion.semaforo,
            )
        )

    return dataset


@router.get("/dataset", response_model=list[MlDatasetItem], dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))])
def get_ml_dataset(
    session: Session = Depends(get_session),
) -> list[MlDatasetItem]:
    return _build_dataset(session)


@router.get("/dataset.csv", dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))])
def get_ml_dataset_csv(
    session: Session = Depends(get_session),
) -> Response:
    dataset = _build_dataset(session)

    output = io.StringIO()
    fieldnames = list(MlDatasetItem.model_fields.keys())

    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()

    for item in dataset:
        writer.writerow(item.model_dump())

    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={
            "Content-Disposition": "attachment; filename=ml_dataset.csv",
        },
    )


