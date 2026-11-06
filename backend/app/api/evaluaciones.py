import hashlib
import json
import logging
from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlmodel import Session, select

from app.core.security import require_roles
from app.db.session import get_session
from app.models.evaluation import DetalleEvaluacion, Evaluacion
from app.models.prediction import PrediccionModelo
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.evaluation_sync import (
    EvaluationSyncRequest,
    EvaluationSyncResponse,
    SyncedEvaluationOut,
)
from app.services.ml_predictor import (
    build_features_from_sync,
    get_model_status,
    predict_risk_from_sync,
)
from app.services.risk_calculator import calculate_risk_from_session
from app.services.ml_risk_predictor import predict_risk_with_ml
from app.services.adaptive_level_service import update_student_level_for_test_type

router = APIRouter(
    prefix="/api/v1/evaluaciones",
    tags=["evaluaciones"],
)
logger = logging.getLogger(__name__)


def _count_complexity_details(local_details) -> dict[str, int]:
    totals = {
        "BAJA": 0,
        "MEDIA": 0,
        "ALTA": 0,
    }

    for detail in local_details:
        complexity = (detail.complejidad_estimulo or "").strip().upper()

        if complexity in totals:
            totals[complexity] += 1

    return totals


def _non_negative(value: int | None) -> int:
    if value is None:
        return 0

    return max(0, int(value))


def _resolve_adaptive_distribution(
    *,
    local_session,
    local_details,
) -> tuple[int, int, int]:
    supplied_total = (
        _non_negative(local_session.total_baja)
        + _non_negative(local_session.total_media)
        + _non_negative(local_session.total_alta)
    )

    if supplied_total > 0:
        return (
            _non_negative(local_session.total_baja),
            _non_negative(local_session.total_media),
            _non_negative(local_session.total_alta),
        )

    counted = _count_complexity_details(local_details)

    return counted["BAJA"], counted["MEDIA"], counted["ALTA"]


def _authorized_students(payload, current_user, session) -> dict[int, Estudiante]:
    student_ids = sorted({item.estudiante_id for item in payload.sessions})
    students = session.exec(
        select(Estudiante)
        .where(Estudiante.id.in_(student_ids))
        .order_by(Estudiante.id)
        .with_for_update()
    ).all()
    by_id = {student.id: student for student in students}
    if len(by_id) != len(student_ids):
        raise HTTPException(404, "No se encontró un estudiante del lote.")
    if current_user.rol.upper() == "MAESTRO":
        allowed = set(session.exec(
            select(DocenteSeccion.seccion_id).where(
                DocenteSeccion.usuario_id == current_user.id,
            )
        ).all())
        if any(student.seccion_id not in allowed for student in students):
            raise HTTPException(403, "Solo puede enviar evaluaciones de sus secciones asignadas.")
    return by_id


def _payload_hash(local_session, local_details) -> str:
    canonical = {
        "session": local_session.model_dump(mode="json"),
        "details": [
            item.model_dump(mode="json")
            for item in sorted(local_details, key=lambda item: item.local_detail_id)
        ],
    }
    return hashlib.sha256(json.dumps(
        canonical, sort_keys=True, ensure_ascii=False, separators=(",", ":"),
    ).encode("utf-8")).hexdigest()


def _existing_confirmation(existing, student, payload_hash, session):
    if existing.sync_payload_hash != payload_hash:
        raise HTTPException(409, "La sesión ya fue recibida con un contenido diferente.")
    prediction = session.exec(
        select(PrediccionModelo).where(PrediccionModelo.evaluacion_id == existing.id)
    ).first()
    count = session.exec(
        select(func.count()).select_from(DetalleEvaluacion).where(
            DetalleEvaluacion.evaluacion_id == existing.id,
        )
    ).one()
    if prediction is None or count != existing.total_items:
        logger.error("Una sesión recibida requiere revisión de integridad.")
        raise HTTPException(503, "No se pudo confirmar la evaluación guardada. Vuelva a intentarlo.")
    return SyncedEvaluationOut(
        local_session_id=existing.local_session_id,
        evaluacion_id=existing.id,
        details_inserted=0,
        details_confirmed=count,
        porcentaje_riesgo=existing.porcentaje_riesgo,
        semaforo=existing.semaforo,
        fuente_prediccion=prediction.fuente_prediccion,
        modelo_nombre=prediction.modelo_nombre,
        nivel_actualizado=(
            student.nivel_lectura if existing.tipo_prueba == "LECTURA"
            else student.nivel_fonologia
        ),
        nivel_lectura=student.nivel_lectura,
        nivel_fonologia=student.nivel_fonologia,
        cambio_nivel="MANTIENE",
    )


def _save_sync_batch(payload, current_user, session) -> EvaluationSyncResponse:
    students = _authorized_students(payload, current_user, session)
    details_by_local_session = defaultdict(list)

    for detail in payload.details:
        details_by_local_session[detail.local_session_id].append(detail)

    synced_items: list[SyncedEvaluationOut] = []
    total_details_inserted = 0
    evaluations_inserted = 0

    for local_session in payload.sessions:
        local_details = details_by_local_session.get(
            local_session.local_session_id,
            [],
        )
        payload_hash = _payload_hash(local_session, local_details)
        student = students[local_session.estudiante_id]
        existing = session.exec(
            select(Evaluacion).where(
                Evaluacion.local_session_id == local_session.local_session_id,
            )
        ).first()
        if existing is not None:
            synced_items.append(
                _existing_confirmation(existing, student, payload_hash, session)
            )
            continue
        section = session.get(Seccion, student.seccion_id) if student.seccion_id else None
        if (
            not student.activo
            or not student.consentimiento_firmado
            or student.fecha_consentimiento is None
            or section is None
            or not section.activo
        ):
            raise HTTPException(
                409,
                "Un estudiante no está habilitado para enviar evaluaciones. "
                "El docente debe revisar su estado, sección y consentimiento.",
            )

        features = build_features_from_sync(
            local_session=local_session,
            local_details=local_details,
        )

        try:
            ml_result = predict_risk_with_ml(features)

            porcentaje_riesgo = ml_result["porcentaje_riesgo"]
            semaforo = ml_result["semaforo"]
            fuente_prediccion = ml_result["fuente_prediccion"]
            modelo_nombre = ml_result["modelo_nombre"]
            modelo_version = ml_result["modelo_version"]
            probabilidades = {}
        except Exception as exc:
            logger.warning("Se utilizará el modelo de respaldo: %s.", type(exc).__name__)

            ml_prediction = predict_risk_from_sync(
                local_session=local_session,
                local_details=local_details,
            )

            if ml_prediction is None:
                porcentaje_riesgo, semaforo = calculate_risk_from_session(
                    total_items=local_session.total_items,
                    aciertos_primer_intento=local_session.aciertos_primer_intento,
                    taps_erroneos_totales=local_session.taps_erroneos_totales,
                    tiempo_promedio_ms=local_session.tiempo_promedio_ms,
                )

                fuente_prediccion = "HEURISTICA"
                modelo_nombre = "risk_calculator_v0.1"
                modelo_version = "v0.1-demo"
                probabilidades = {}
            else:
                porcentaje_riesgo = ml_prediction.porcentaje_riesgo
                semaforo = ml_prediction.semaforo
                fuente_prediccion = ml_prediction.fuente_prediccion
                modelo_nombre = ml_prediction.modelo_nombre
                modelo_version = ml_prediction.modelo_version
                probabilidades = ml_prediction.probabilidades
                features = ml_prediction.features

        total_baja, total_media, total_alta = _resolve_adaptive_distribution(
            local_session=local_session,
            local_details=local_details,
        )

        evaluacion = Evaluacion(
            local_session_id=local_session.local_session_id,
            sync_payload_hash=payload_hash,
            estudiante_id=local_session.estudiante_id,
            fecha_evaluacion=local_session.fecha_fin.replace(tzinfo=None),
            porcentaje_riesgo=porcentaje_riesgo,
            semaforo=semaforo,
            tipo_prueba=local_session.tipo_prueba,
            total_items=local_session.total_items,
            aciertos_primer_intento=local_session.aciertos_primer_intento,
            taps_erroneos_totales=local_session.taps_erroneos_totales,
            tiempo_promedio_ms=local_session.tiempo_promedio_ms,
            nivel_dificultad_aplicado=local_session.nivel_dificultad_aplicado,
            total_baja=total_baja,
            total_media=total_media,
            total_alta=total_alta,
            version_banco_palabras=local_session.version_banco_palabras,
        )

        session.add(evaluacion)
        session.flush()

        prediccion = PrediccionModelo(
            evaluacion_id=evaluacion.id,
            fuente_prediccion=fuente_prediccion,
            modelo_nombre=modelo_nombre,
            modelo_version=modelo_version,
            porcentaje_riesgo=porcentaje_riesgo,
            semaforo=semaforo,
            probabilidad_verde=probabilidades.get("VERDE"),
            probabilidad_amarillo=probabilidades.get("AMARILLO"),
            probabilidad_rojo=probabilidades.get("ROJO"),
            feature_vector_json=json.dumps(
                features,
                ensure_ascii=False,
            ),
            probabilidades_json=json.dumps(
                probabilidades,
                ensure_ascii=False,
            ),
        )

        session.add(prediccion)
        session.flush()

        level_result = update_student_level_for_test_type(
            session=session,
            estudiante_id=local_session.estudiante_id,
            tipo_prueba=local_session.tipo_prueba,
        )

        inserted_for_session = 0

        for local_detail in local_details:
            detalle = DetalleEvaluacion(
                evaluacion_id=evaluacion.id,
                tipo_prueba=local_detail.tipo_prueba,
                tiempo_respuesta_ms=local_detail.tiempo_respuesta_ms,
                duracion_drag_drop_ms=local_detail.duracion_drag_drop_ms,
                taps_erroneos=local_detail.taps_erroneos,
                tipo_error=local_detail.tipo_error,
                complejidad_estimulo=local_detail.complejidad_estimulo,
                acierto=local_detail.acierto,
                stimulus_id=local_detail.stimulus_id,
                texto=local_detail.texto,
            )

            session.add(detalle)
            inserted_for_session += 1

        session.flush()

        total_details_inserted += inserted_for_session
        evaluations_inserted += 1

        nivel_actualizado = None
        nivel_lectura = None
        nivel_fonologia = None
        cambio_nivel = None

        if level_result is not None:
            nivel_actualizado = level_result.nivel_actualizado
            nivel_lectura = level_result.nivel_lectura
            nivel_fonologia = level_result.nivel_fonologia
            cambio_nivel = level_result.cambio_nivel

        synced_items.append(
            SyncedEvaluationOut(
                local_session_id=local_session.local_session_id,
                evaluacion_id=evaluacion.id,
                details_inserted=inserted_for_session,
                details_confirmed=len(local_details),
                porcentaje_riesgo=porcentaje_riesgo,
                semaforo=semaforo,
                fuente_prediccion=fuente_prediccion,
                modelo_nombre=modelo_nombre,
                nivel_actualizado=nivel_actualizado,
                nivel_lectura=nivel_lectura,
                nivel_fonologia=nivel_fonologia,
                cambio_nivel=cambio_nivel,
            )
        )

    return EvaluationSyncResponse(
        status="ok",
        sessions_received=len(payload.sessions),
        details_received=len(payload.details),
        evaluations_inserted=evaluations_inserted,
        details_inserted=total_details_inserted,
        synced=synced_items,
    )


def _is_session_conflict(error: IntegrityError) -> bool:
    diagnostic = getattr(error.orig, "diag", None)
    constraint = getattr(diagnostic, "constraint_name", None)
    if constraint == "ix_evaluaciones_local_session_id":
        return True
    return "UNIQUE constraint failed: evaluaciones.local_session_id" in str(error.orig)


@router.post("/sync", response_model=EvaluationSyncResponse)
def sync_evaluaciones(
    payload: EvaluationSyncRequest,
    current_user: Usuario = Depends(require_roles("DIRECTORA", "MAESTRO")),
    session: Session = Depends(get_session),
) -> EvaluationSyncResponse:
    for attempt in range(2):
        try:
            result = _save_sync_batch(payload, current_user, session)
            session.commit()
            return result
        except IntegrityError as error:
            session.rollback()
            if attempt == 0 and _is_session_conflict(error):
                continue
            logger.warning("Conflicto de integridad al sincronizar evaluaciones.")
            raise HTTPException(
                409, "No se pudo guardar el lote. Las evaluaciones siguen pendientes.",
            ) from error
        except SQLAlchemyError as error:
            session.rollback()
            logger.error("Error de base de datos al sincronizar: %s.", type(error).__name__)
            raise HTTPException(
                503, "No se pudo guardar el lote. Vuelva a intentarlo.",
            ) from error
        except HTTPException:
            session.rollback()
            raise
    raise RuntimeError("No se pudo completar la sincronización.")


@router.get("/debug", dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))])
def list_evaluaciones(
    session: Session = Depends(get_session),
):
    evaluaciones = session.exec(select(Evaluacion)).all()
    detalles = session.exec(select(DetalleEvaluacion)).all()
    predicciones = session.exec(select(PrediccionModelo)).all()

    return {
        "evaluaciones_count": len(evaluaciones),
        "detalles_count": len(detalles),
        "predicciones_count": len(predicciones),
        "evaluaciones": evaluaciones,
        "detalles": detalles,
        "predicciones": predicciones,
    }


@router.get("/model-status", dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))])
def model_status():
    return get_model_status()

