from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.core.security import get_current_user
from app.db.session import get_session
from app.models.jornada import JornadaEvaluacion
from app.models.section import DocenteSeccion, Seccion
from app.models.user import Usuario
from app.schemas.jornada_schema import JornadaActivateRequest, JornadaPublic


router = APIRouter(
    prefix="/api/v1/jornadas-evaluacion",
    tags=["jornadas-evaluacion"],
)


def _raise_forbidden() -> None:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tienes permisos para esta operación.",
    )


def _get_docente_section_ids(
    usuario: Usuario,
    session: Session,
) -> set[int]:
    if usuario.id is None:
        return set()

    links = session.exec(
        select(DocenteSeccion).where(
            DocenteSeccion.usuario_id == usuario.id,
        )
    ).all()

    return {
        link.seccion_id
        for link in links
    }


def _ensure_section_exists(seccion_id: int, session: Session) -> Seccion:
    seccion = session.get(Seccion, seccion_id)

    if seccion is None:
        raise HTTPException(
            status_code=404,
            detail="Sección no encontrada.",
        )

    if not seccion.activo:
        raise HTTPException(
            status_code=400,
            detail="La sección no está activa.",
        )

    return seccion


def _ensure_user_can_manage_section(
    usuario: Usuario,
    seccion_id: int,
    session: Session,
) -> None:
    rol = usuario.rol.upper()

    _ensure_section_exists(seccion_id, session)

    if rol == "DIRECTORA":
        return

    if rol == "MAESTRO":
        allowed_ids = _get_docente_section_ids(usuario, session)

        if seccion_id in allowed_ids:
            return

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El docente solo puede gestionar jornadas de sus secciones asignadas.",
        )

    _raise_forbidden()


def _expire_jornada_if_needed(
    jornada: JornadaEvaluacion,
    session: Session,
) -> JornadaEvaluacion:
    now = datetime.utcnow()

    if (
        jornada.estado == "ACTIVA"
        and jornada.fecha_expiracion is not None
        and jornada.fecha_expiracion <= now
    ):
        jornada.estado = "EXPIRADA"
        jornada.fecha_cierre = now
        jornada.updated_at = now
        session.add(jornada)
        session.commit()
        session.refresh(jornada)

    return jornada


def _get_active_jornada(
    seccion_id: int,
    session: Session,
) -> JornadaEvaluacion | None:
    jornada = session.exec(
        select(JornadaEvaluacion)
        .where(
            JornadaEvaluacion.seccion_id == seccion_id,
            JornadaEvaluacion.estado == "ACTIVA",
        )
        .order_by(JornadaEvaluacion.fecha_inicio.desc())
    ).first()

    if jornada is None:
        return None

    jornada = _expire_jornada_if_needed(jornada, session)

    if jornada.estado != "ACTIVA":
        return None

    return jornada


@router.post(
    "/activar",
    response_model=JornadaPublic,
)
def activar_jornada(
    payload: JornadaActivateRequest,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> JornadaPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    if not payload.prueba_lectura_activa and not payload.prueba_fonologia_activa:
        raise HTTPException(
            status_code=400,
            detail="Debe activar al menos una prueba.",
        )

    _ensure_user_can_manage_section(
        usuario=current_user,
        seccion_id=payload.seccion_id,
        session=session,
    )

    active_jornada = _get_active_jornada(
        seccion_id=payload.seccion_id,
        session=session,
    )

    if active_jornada is not None:
        raise HTTPException(
            status_code=400,
            detail="Ya existe una jornada activa para esta sección.",
        )

    now = datetime.utcnow()

    jornada = JornadaEvaluacion(
        seccion_id=payload.seccion_id,
        responsable_id=current_user.id,
        fecha_inicio=now,
        fecha_expiracion=now + timedelta(hours=payload.duracion_horas),
        estado="ACTIVA",
        prueba_lectura_activa=payload.prueba_lectura_activa,
        prueba_fonologia_activa=payload.prueba_fonologia_activa,
        created_at=now,
        updated_at=now,
    )

    session.add(jornada)
    session.commit()
    session.refresh(jornada)

    return JornadaPublic.model_validate(jornada)


@router.get(
    "/activa/{seccion_id}",
    response_model=JornadaPublic,
)
def obtener_jornada_activa(
    seccion_id: int,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> JornadaPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO", "PSICOLOGA"}:
        _raise_forbidden()

    if current_user.rol.upper() == "MAESTRO":
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=seccion_id,
            session=session,
        )
    else:
        _ensure_section_exists(seccion_id, session)

    jornada = _get_active_jornada(
        seccion_id=seccion_id,
        session=session,
    )

    if jornada is None:
        raise HTTPException(
            status_code=404,
            detail="No hay jornada activa para esta sección.",
        )

    return JornadaPublic.model_validate(jornada)


@router.get(
    "",
    response_model=list[JornadaPublic],
)
def listar_jornadas(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[JornadaPublic]:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO", "PSICOLOGA"}:
        _raise_forbidden()

    statement = select(JornadaEvaluacion).order_by(
        JornadaEvaluacion.fecha_inicio.desc()
    )

    if current_user.rol.upper() == "MAESTRO":
        allowed_ids = _get_docente_section_ids(current_user, session)

        if not allowed_ids:
            return []

        statement = statement.where(
            JornadaEvaluacion.seccion_id.in_(list(allowed_ids))
        )

    jornadas = session.exec(statement).all()

    result: list[JornadaPublic] = []

    for jornada in jornadas:
        jornada = _expire_jornada_if_needed(jornada, session)
        result.append(JornadaPublic.model_validate(jornada))

    return result


@router.patch(
    "/{jornada_id}/cerrar",
    response_model=JornadaPublic,
)
def cerrar_jornada(
    jornada_id: int,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> JornadaPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    jornada = session.get(JornadaEvaluacion, jornada_id)

    if jornada is None:
        raise HTTPException(
            status_code=404,
            detail="Jornada no encontrada.",
        )

    _ensure_user_can_manage_section(
        usuario=current_user,
        seccion_id=jornada.seccion_id,
        session=session,
    )

    now = datetime.utcnow()

    jornada.estado = "CERRADA"
    jornada.fecha_cierre = now
    jornada.updated_at = now

    session.add(jornada)
    session.commit()
    session.refresh(jornada)

    return JornadaPublic.model_validate(jornada)

