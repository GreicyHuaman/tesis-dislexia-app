import json
from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlmodel import Session, select

from app.core.security import get_current_user
from app.db.session import get_session
from app.models.evaluation import Evaluacion
from app.models.section import DocenteSeccion
from app.models.seguimiento import SeguimientoEstudiante
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.seguimiento_schema import (
    SeguimientoHistorialResponse,
    SeguimientoItem,
    SeguimientoObservacionCreate,
    SeguimientoPublic,
    SeguimientoResumenResponse,
    SeguimientoUpdate,
)

router = APIRouter(
    prefix="/api/v1/seguimiento",
    tags=["seguimiento"],
)


def _raise_forbidden() -> None:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tienes permisos para esta operación.",
    )


def _get_docente_section_ids(
    usuario: Usuario,
    session: Session,
) -> list[int]:
    if usuario.id is None:
        return []

    links = session.exec(
        select(DocenteSeccion).where(
            DocenteSeccion.usuario_id == usuario.id,
        )
    ).all()

    return [
        link.seccion_id
        for link in links
    ]


def _get_allowed_section_ids_for_user(
    usuario: Usuario,
    session: Session,
) -> list[int] | None:
    rol = usuario.rol.upper()

    if rol == "MAESTRO":
        return _get_docente_section_ids(usuario, session)

    if rol in {"DIRECTORA", "PSICOLOGA"}:
        return None

    return []


def _ensure_tracking_role(usuario: Usuario) -> None:
    if usuario.rol.upper() not in {"DIRECTORA", "MAESTRO", "PSICOLOGA"}:
        _raise_forbidden()


def _student_name(estudiante: Estudiante) -> str:
    return f"{estudiante.nombres} {estudiante.apellidos}".strip()


def _list_allowed_students(
    usuario: Usuario,
    session: Session,
    seccion_id: int | None = None,
) -> list[Estudiante]:
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=usuario,
        session=session,
    )

    if allowed_section_ids == []:
        return []

    statement = (
        select(Estudiante)
        .where(
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
        .order_by(Estudiante.apellidos, Estudiante.nombres)
    )

    if allowed_section_ids is not None:
        statement = statement.where(
            Estudiante.seccion_id.in_(allowed_section_ids),
        )

    if seccion_id is not None:
        if allowed_section_ids is not None and seccion_id not in allowed_section_ids:
            _raise_forbidden()

        statement = statement.where(Estudiante.seccion_id == seccion_id)

    return session.exec(statement).all()


def _ensure_user_can_access_student(
    usuario: Usuario,
    estudiante: Estudiante,
    session: Session,
) -> None:
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=usuario,
        session=session,
    )

    if allowed_section_ids == []:
        _raise_forbidden()

    if allowed_section_ids is None:
        return

    if estudiante.seccion_id not in allowed_section_ids:
        _raise_forbidden()


def _student_evaluations(
    estudiante_id: int,
    session: Session,
) -> list[Evaluacion]:
    return session.exec(
        select(Evaluacion)
        .where(Evaluacion.estudiante_id == estudiante_id)
        .order_by(Evaluacion.fecha_evaluacion.desc())
    ).all()


def _latest_tracking(
    estudiante_id: int,
    session: Session,
) -> SeguimientoEstudiante | None:
    return session.exec(
        select(SeguimientoEstudiante)
        .where(SeguimientoEstudiante.estudiante_id == estudiante_id)
        .order_by(SeguimientoEstudiante.fecha_seguimiento.desc())
    ).first()


def _decode_categories(raw: str | None) -> list[str]:
    if not raw:
        return []

    try:
        decoded = json.loads(raw)

        if isinstance(decoded, list):
            return [str(item) for item in decoded]
    except Exception:
        return []

    return []


def _week_iso(value: datetime | None = None) -> str:
    current = value or datetime.utcnow()
    iso = current.isocalendar()

    return f"{iso.year}-W{iso.week:02d}"


def _weekly_state(
    latest_evaluation: Evaluacion | None,
) -> tuple[str, date | None, int | None]:
    if latest_evaluation is None:
        return "SIN_EVALUACION", None, None

    today = datetime.utcnow().date()
    latest_date = latest_evaluation.fecha_evaluacion.date()
    next_date = latest_date + timedelta(days=7)
    days_since = (today - latest_date).days

    if today < next_date:
        return "AL_DIA", next_date, days_since

    if today == next_date:
        return "VENCE_HOY", next_date, days_since

    return "VENCIDA", next_date, days_since


def _trend(evaluations: list[Evaluacion]) -> str:
    if len(evaluations) < 2:
        return "SIN_HISTORIAL"

    current = evaluations[0].porcentaje_riesgo
    previous = evaluations[1].porcentaje_riesgo

    if current is None or previous is None:
        return "SIN_HISTORIAL"

    if current < previous - 5:
        return "MEJORA"

    if current > previous + 5:
        return "EMPEORA"

    return "ESTABLE"


def _priority(
    *,
    estado_semanal: str,
    semaforo: str | None,
    tendencia: str,
) -> str:
    normalized_semaforo = (semaforo or "").upper()

    if normalized_semaforo == "ROJO":
        return "ALTA"

    if estado_semanal == "SIN_EVALUACION":
        return "ALTA"

    if estado_semanal == "VENCIDA":
        if normalized_semaforo == "VERDE":
            return "MEDIA"

        return "ALTA"

    if normalized_semaforo == "AMARILLO" and tendencia == "EMPEORA":
        return "ALTA"

    if normalized_semaforo == "AMARILLO":
        return "MEDIA"

    return "BAJA"


def _suggested_action(
    *,
    estado_semanal: str,
    semaforo: str | None,
    tendencia: str,
) -> str:
    normalized_semaforo = (semaforo or "").upper()

    if estado_semanal == "SIN_EVALUACION":
        return "Programar primera evaluación semanal."

    if estado_semanal == "VENCIDA":
        return "Reprogramar evaluación semanal y registrar observación."

    if normalized_semaforo == "ROJO":
        return "Registrar observación obligatoria y considerar derivación sugerida."

    if normalized_semaforo == "AMARILLO" and tendencia == "EMPEORA":
        return "Aplicar reforzamiento y seguimiento cercano."

    if normalized_semaforo == "AMARILLO":
        return "Registrar observación recomendada y reforzamiento."

    return "Continuar seguimiento semanal."


def _build_tracking_item(
    estudiante: Estudiante,
    session: Session,
) -> SeguimientoItem:
    evaluations = _student_evaluations(
        estudiante_id=estudiante.id or 0,
        session=session,
    )
    latest_evaluation = evaluations[0] if evaluations else None
    tracking = _latest_tracking(
        estudiante_id=estudiante.id or 0,
        session=session,
    )

    estado_semanal, proxima_evaluacion, dias_desde_ultima = _weekly_state(
        latest_evaluation,
    )
    tendencia = _trend(evaluations)
    semaforo = latest_evaluation.semaforo if latest_evaluation else None
    porcentaje_riesgo = (
        latest_evaluation.porcentaje_riesgo
        if latest_evaluation
        else None
    )
    prioridad = _priority(
        estado_semanal=estado_semanal,
        semaforo=semaforo,
        tendencia=tendencia,
    )
    accion = _suggested_action(
        estado_semanal=estado_semanal,
        semaforo=semaforo,
        tendencia=tendencia,
    )

    return SeguimientoItem(
        estudiante_id=estudiante.id or 0,
        estudiante_nombre=_student_name(estudiante),
        seccion_id=estudiante.seccion_id,
        seguimiento_id=tracking.id if tracking else None,
        evaluacion_id=latest_evaluation.id if latest_evaluation else None,
        ultima_fecha_evaluacion=(
            latest_evaluation.fecha_evaluacion
            if latest_evaluation
            else None
        ),
        dias_desde_ultima_evaluacion=dias_desde_ultima,
        porcentaje_riesgo=porcentaje_riesgo,
        semaforo=semaforo,
        estado_semanal=estado_semanal,
        prioridad=prioridad,
        tendencia=tendencia,
        accion_sugerida=accion,
        proxima_evaluacion=proxima_evaluacion,
        observacion_docente=(
            tracking.observacion_docente
            if tracking
            else None
        ),
        categorias=_decode_categories(
            tracking.categorias_json if tracking else None,
        ),
        estado=tracking.estado if tracking else None,
        responsable_nombre=tracking.responsable_nombre if tracking else None,
    )


def _observation_required(
    *,
    latest_item: SeguimientoItem,
    requested_estado: str,
) -> bool:
    if (latest_item.semaforo or "").upper() == "ROJO":
        return True

    if requested_estado.upper() in {
        "DERIVACION_SUGERIDA",
        "CERRADO",
        "CAMBIO_MANUAL",
    }:
        return True

    return False


@router.get("/resumen", response_model=SeguimientoResumenResponse)
def get_seguimiento_resumen(
    seccion_id: int | None = Query(default=None),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> SeguimientoResumenResponse:
    _ensure_tracking_role(current_user)

    students = _list_allowed_students(
        usuario=current_user,
        session=session,
        seccion_id=seccion_id,
    )

    items = [
        _build_tracking_item(estudiante, session)
        for estudiante in students
    ]

    return SeguimientoResumenResponse(
        total_estudiantes=len(items),
        sin_evaluacion=sum(1 for item in items if item.estado_semanal == "SIN_EVALUACION"),
        al_dia=sum(1 for item in items if item.estado_semanal == "AL_DIA"),
        vence_hoy=sum(1 for item in items if item.estado_semanal == "VENCE_HOY"),
        vencida=sum(1 for item in items if item.estado_semanal == "VENCIDA"),
        prioridad_alta=sum(1 for item in items if item.prioridad == "ALTA"),
        prioridad_media=sum(1 for item in items if item.prioridad == "MEDIA"),
        prioridad_baja=sum(1 for item in items if item.prioridad == "BAJA"),
    )


@router.get("/priorizados", response_model=list[SeguimientoItem])
def list_seguimiento_priorizados(
    seccion_id: int | None = Query(default=None),
    prioridad: str | None = Query(default=None),
    estado_semanal: str | None = Query(default=None),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[SeguimientoItem]:
    _ensure_tracking_role(current_user)

    students = _list_allowed_students(
        usuario=current_user,
        session=session,
        seccion_id=seccion_id,
    )

    items = [
        _build_tracking_item(estudiante, session)
        for estudiante in students
    ]

    if prioridad:
        items = [
            item
            for item in items
            if item.prioridad == prioridad.strip().upper()
        ]

    if estado_semanal:
        items = [
            item
            for item in items
            if item.estado_semanal == estado_semanal.strip().upper()
        ]

    priority_rank = {
        "ALTA": 0,
        "MEDIA": 1,
        "BAJA": 2,
    }

    return sorted(
        items,
        key=lambda item: (
            priority_rank.get(item.prioridad, 9),
            item.estudiante_nombre,
        ),
    )


@router.get(
    "/estudiante/{estudiante_id}",
    response_model=SeguimientoHistorialResponse,
)
def get_seguimiento_estudiante(
    estudiante_id: int,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> SeguimientoHistorialResponse:
    _ensure_tracking_role(current_user)

    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    _ensure_user_can_access_student(
        usuario=current_user,
        estudiante=estudiante,
        session=session,
    )

    observaciones = session.exec(
        select(SeguimientoEstudiante)
        .where(SeguimientoEstudiante.estudiante_id == estudiante_id)
        .order_by(SeguimientoEstudiante.fecha_seguimiento.desc())
    ).all()

    return SeguimientoHistorialResponse(
        estudiante_id=estudiante.id or estudiante_id,
        estudiante_nombre=_student_name(estudiante),
        seccion_id=estudiante.seccion_id,
        actual=_build_tracking_item(estudiante, session),
        observaciones=[
            SeguimientoPublic.model_validate(item)
            for item in observaciones
        ],
    )


@router.post(
    "/observaciones",
    response_model=SeguimientoPublic,
)
def create_seguimiento_observacion(
    payload: SeguimientoObservacionCreate,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> SeguimientoPublic:
    _ensure_tracking_role(current_user)

    estudiante = session.get(Estudiante, payload.estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    _ensure_user_can_access_student(
        usuario=current_user,
        estudiante=estudiante,
        session=session,
    )

    latest_item = _build_tracking_item(estudiante, session)

    evaluacion_id = payload.evaluacion_id or latest_item.evaluacion_id
    observacion = (payload.observacion_docente or "").strip()

    if _observation_required(
        latest_item=latest_item,
        requested_estado=payload.estado,
    ) and not observacion:
        raise HTTPException(
            status_code=400,
            detail="La observación docente es obligatoria para este caso.",
        )

    responsable_nombre = f"{current_user.nombres} {current_user.apellidos}".strip()

    seguimiento = SeguimientoEstudiante(
        estudiante_id=payload.estudiante_id,
        evaluacion_id=evaluacion_id,
        fecha_seguimiento=datetime.utcnow(),
        semana_iso=_week_iso(),
        porcentaje_riesgo=latest_item.porcentaje_riesgo,
        semaforo=latest_item.semaforo,
        prioridad=latest_item.prioridad,
        tendencia=latest_item.tendencia,
        accion_sugerida=latest_item.accion_sugerida,
        proxima_evaluacion=latest_item.proxima_evaluacion,
        observacion_docente=observacion or None,
        categorias_json=json.dumps(payload.categorias, ensure_ascii=False),
        estado=payload.estado.strip().upper(),
        responsable_id=current_user.id,
        responsable_nombre=responsable_nombre,
        responsable_cargo=current_user.rol,
    )

    session.add(seguimiento)
    session.commit()
    session.refresh(seguimiento)

    return SeguimientoPublic.model_validate(seguimiento)


@router.patch(
    "/{seguimiento_id}",
    response_model=SeguimientoPublic,
)
def update_seguimiento(
    seguimiento_id: int,
    payload: SeguimientoUpdate,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> SeguimientoPublic:
    _ensure_tracking_role(current_user)

    seguimiento = session.get(SeguimientoEstudiante, seguimiento_id)

    if seguimiento is None:
        raise HTTPException(
            status_code=404,
            detail="Seguimiento no encontrado.",
        )

    estudiante = session.get(Estudiante, seguimiento.estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    _ensure_user_can_access_student(
        usuario=current_user,
        estudiante=estudiante,
        session=session,
    )

    if payload.observacion_docente is not None:
        seguimiento.observacion_docente = payload.observacion_docente.strip() or None

    if payload.categorias is not None:
        seguimiento.categorias_json = json.dumps(
            payload.categorias,
            ensure_ascii=False,
        )

    if payload.estado is not None:
        seguimiento.estado = payload.estado.strip().upper()

    if payload.prioridad is not None:
        seguimiento.prioridad = payload.prioridad.strip().upper()

    if payload.accion_sugerida is not None:
        seguimiento.accion_sugerida = payload.accion_sugerida.strip() or None

    if (
        seguimiento.estado in {"DERIVACION_SUGERIDA", "CERRADO", "CAMBIO_MANUAL"}
        and not seguimiento.observacion_docente
    ):
        raise HTTPException(
            status_code=400,
            detail="La observación docente es obligatoria para este cambio.",
        )

    seguimiento.updated_at = datetime.utcnow()

    session.add(seguimiento)
    session.commit()
    session.refresh(seguimiento)

    return SeguimientoPublic.model_validate(seguimiento)
