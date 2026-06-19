import json
from collections import defaultdict

from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.core.security import require_roles
from app.db.session import get_session
from app.models.evaluation import DetalleEvaluacion, Evaluacion
from app.models.prediction import PrediccionModelo
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

router = APIRouter(
    prefix="/api/v1/evaluaciones",
    tags=["evaluaciones"],
)


@router.post("/sync", response_model=EvaluationSyncResponse)
def sync_evaluaciones(
    payload: EvaluationSyncRequest,
    session: Session = Depends(get_session),
) -> EvaluationSyncResponse:
    details_by_local_session = defaultdict(list)

    for detail in payload.details:
        details_by_local_session[detail.local_session_id].append(detail)

    synced_items: list[SyncedEvaluationOut] = []
    total_details_inserted = 0

    for local_session in payload.sessions:
        fecha_evaluacion = (
            local_session.fecha_fin
            or local_session.fecha_inicio
        )

        local_details = details_by_local_session.get(
            local_session.local_session_id,
            [],
        )

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
            features = build_features_from_sync(
                local_session=local_session,
                local_details=local_details,
            )
        else:
            porcentaje_riesgo = ml_prediction.porcentaje_riesgo
            semaforo = ml_prediction.semaforo
            fuente_prediccion = ml_prediction.fuente_prediccion
            modelo_nombre = ml_prediction.modelo_nombre
            modelo_version = ml_prediction.modelo_version
            probabilidades = ml_prediction.probabilidades
            features = ml_prediction.features

        evaluacion = Evaluacion(
            estudiante_id=local_session.estudiante_id,
            fecha_evaluacion=fecha_evaluacion,
            porcentaje_riesgo=porcentaje_riesgo,
            semaforo=semaforo,
            tipo_prueba=local_session.tipo_prueba,
            total_items=local_session.total_items,
            aciertos_primer_intento=local_session.aciertos_primer_intento,
            taps_erroneos_totales=local_session.taps_erroneos_totales,
            tiempo_promedio_ms=local_session.tiempo_promedio_ms,
        )

        session.add(evaluacion)
        session.commit()
        session.refresh(evaluacion)

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
        session.commit()

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

        session.commit()

        total_details_inserted += inserted_for_session

        synced_items.append(
            SyncedEvaluationOut(
                local_session_id=local_session.local_session_id,
                evaluacion_id=evaluacion.id,
                details_inserted=inserted_for_session,
                porcentaje_riesgo=porcentaje_riesgo,
                semaforo=semaforo,
                fuente_prediccion=fuente_prediccion,
                modelo_nombre=modelo_nombre,
            )
        )

    return EvaluationSyncResponse(
        status="ok",
        sessions_received=len(payload.sessions),
        details_received=len(payload.details),
        evaluations_inserted=len(synced_items),
        details_inserted=total_details_inserted,
        synced=synced_items,
    )


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

