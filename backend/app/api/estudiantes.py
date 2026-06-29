from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.core.security import get_current_user
from app.db.session import get_session
from app.models.jornada import JornadaEvaluacion
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.student_schema import (
    StudentAdminPublic,
    StudentCreate,
    StudentOfflineCacheItem,
    StudentPublic,
    StudentUpdate,
)
from app.services.pin_generator import (
    PinValidationError,
    generate_unique_pin,
    validate_pin_rules,
)

router = APIRouter(
    prefix="/api/v1/estudiantes",
    tags=["estudiantes"],
)


def _raise_forbidden() -> None:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tienes permisos para esta operación.",
    )


def _validate_pin(pin_corto: str) -> None:
    try:
        validate_pin_rules(pin_corto)
    except PinValidationError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc


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


def _get_allowed_section_ids_for_user(
    usuario: Usuario,
    session: Session,
) -> set[int] | None:
    rol = usuario.rol.upper()

    if rol == "MAESTRO":
        return _get_docente_section_ids(usuario, session)

    if rol in {"DIRECTORA", "PSICOLOGA"}:
        return None

    return set()


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
            detail="El docente solo puede gestionar estudiantes de sus secciones asignadas.",
        )

    _raise_forbidden()


def _validate_consentimiento(payload: StudentCreate | StudentUpdate) -> None:
    consentimiento = getattr(payload, "consentimiento_firmado", None)
    fecha = getattr(payload, "fecha_consentimiento", None)

    if consentimiento is False:
        raise HTTPException(
            status_code=400,
            detail="Solo se puede activar estudiantes con consentimiento firmado.",
        )

    if consentimiento is True and fecha is None:
        raise HTTPException(
            status_code=400,
            detail="Debe registrar la fecha del consentimiento firmado.",
        )


def _get_existing_active_pins(
    session: Session,
    exclude_student_id: int | None = None,
) -> set[str]:
    statement = select(Estudiante).where(
        Estudiante.activo == True,  # noqa: E712
    )

    if exclude_student_id is not None:
        statement = statement.where(Estudiante.id != exclude_student_id)

    estudiantes = session.exec(statement).all()

    return {
        estudiante.pin_corto
        for estudiante in estudiantes
        if estudiante.pin_corto
    }


def _ensure_pin_is_unique(
    pin_corto: str,
    session: Session,
    exclude_student_id: int | None = None,
) -> None:
    statement = select(Estudiante).where(
        Estudiante.pin_corto == pin_corto,
        Estudiante.activo == True,  # noqa: E712
    )

    if exclude_student_id is not None:
        statement = statement.where(Estudiante.id != exclude_student_id)

    existing_student = session.exec(statement).first()

    if existing_student is not None:
        raise HTTPException(
            status_code=400,
            detail="Ya existe un estudiante activo con ese PIN.",
        )


def _generate_pin_for_student(
    session: Session,
    exclude_student_id: int | None = None,
) -> str:
    existing_pins = _get_existing_active_pins(
        session=session,
        exclude_student_id=exclude_student_id,
    )

    return generate_unique_pin(existing_pins)


def _apply_student_filters_for_user(
    statement,
    usuario: Usuario,
    session: Session,
):
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=usuario,
        session=session,
    )

    if allowed_section_ids is None:
        return statement

    if not allowed_section_ids:
        return None

    return statement.where(
        Estudiante.seccion_id.in_(list(allowed_section_ids)),
    )


@router.post(
    "",
    response_model=StudentAdminPublic,
)
def create_estudiante(
    payload: StudentCreate,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentAdminPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    _ensure_user_can_manage_section(
        usuario=current_user,
        seccion_id=payload.seccion_id,
        session=session,
    )

    _validate_consentimiento(payload)

    if payload.pin_corto:
        _validate_pin(payload.pin_corto)
        _ensure_pin_is_unique(payload.pin_corto, session)
        pin_corto = payload.pin_corto
    else:
        pin_corto = _generate_pin_for_student(session)

    estudiante = Estudiante(
        codigo_estudiante=(
            payload.codigo_estudiante.strip()
            if payload.codigo_estudiante
            else None
        ),
        nombres=payload.nombres.strip(),
        apellidos=payload.apellidos.strip(),
        fecha_nacimiento=payload.fecha_nacimiento,
        pin_corto=pin_corto,
        seccion_id=payload.seccion_id,
        consentimiento_firmado=payload.consentimiento_firmado,
        fecha_consentimiento=payload.fecha_consentimiento,
        nivel_lectura=1,
        nivel_fonologia=1,
        activo=payload.activo,
    )

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentAdminPublic.model_validate(estudiante)


@router.get(
    "",
    response_model=list[StudentPublic],
)
def list_estudiantes(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[StudentPublic]:
    if current_user.rol.upper() not in {"MAESTRO", "PSICOLOGA", "DIRECTORA"}:
        _raise_forbidden()

    statement = select(Estudiante).order_by(
        Estudiante.apellidos,
        Estudiante.nombres,
    )

    statement = _apply_student_filters_for_user(
        statement=statement,
        usuario=current_user,
        session=session,
    )

    if statement is None:
        return []

    estudiantes = session.exec(statement).all()

    return [
        StudentPublic.model_validate(estudiante)
        for estudiante in estudiantes
    ]


@router.get(
    "/admin/list",
    response_model=list[StudentAdminPublic],
)
def list_estudiantes_admin(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[StudentAdminPublic]:
    if current_user.rol.upper() not in {"MAESTRO", "PSICOLOGA", "DIRECTORA"}:
        _raise_forbidden()

    statement = select(Estudiante).order_by(
        Estudiante.apellidos,
        Estudiante.nombres,
    )

    statement = _apply_student_filters_for_user(
        statement=statement,
        usuario=current_user,
        session=session,
    )

    if statement is None:
        return []

    estudiantes = session.exec(statement).all()

    return [
        StudentAdminPublic.model_validate(estudiante)
        for estudiante in estudiantes
    ]


@router.get(
    "/offline-cache",
    response_model=list[StudentOfflineCacheItem],
)
def list_estudiantes_for_offline_cache(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[StudentOfflineCacheItem]:
    if current_user.rol.upper() not in {"MAESTRO", "PSICOLOGA", "DIRECTORA"}:
        _raise_forbidden()

    statement = (
        select(Estudiante)
        .where(
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
        .order_by(Estudiante.id)
    )

    statement = _apply_student_filters_for_user(
        statement=statement,
        usuario=current_user,
        session=session,
    )

    if statement is None:
        return []

    estudiantes = session.exec(statement).all()

    result: list[StudentOfflineCacheItem] = []

    for estudiante in estudiantes:
        if estudiante.id is None:
            continue

        if not estudiante.pin_corto:
            continue

        result.append(
            StudentOfflineCacheItem(
                id=estudiante.id,
                codigo_estudiante=estudiante.codigo_estudiante,
                nombres=estudiante.nombres,
                apellidos=estudiante.apellidos,
                fecha_nacimiento=estudiante.fecha_nacimiento,
                pin_corto=estudiante.pin_corto,
                seccion_id=estudiante.seccion_id,
                consentimiento_firmado=estudiante.consentimiento_firmado,
                nivel_lectura=estudiante.nivel_lectura,
                nivel_fonologia=estudiante.nivel_fonologia,
                activo=estudiante.activo,
            )
        )

    return result


@router.patch(
    "/{estudiante_id}",
    response_model=StudentAdminPublic,
)
def update_estudiante(
    estudiante_id: int,
    payload: StudentUpdate,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentAdminPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    if estudiante.seccion_id is not None:
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=estudiante.seccion_id,
            session=session,
        )

    if payload.seccion_id is not None:
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=payload.seccion_id,
            session=session,
        )
        estudiante.seccion_id = payload.seccion_id

    if payload.pin_corto is not None:
        _validate_pin(payload.pin_corto)
        _ensure_pin_is_unique(
            pin_corto=payload.pin_corto,
            session=session,
            exclude_student_id=estudiante_id,
        )
        estudiante.pin_corto = payload.pin_corto

    if payload.codigo_estudiante is not None:
        estudiante.codigo_estudiante = payload.codigo_estudiante.strip()

    if payload.nombres is not None:
        estudiante.nombres = payload.nombres.strip()

    if payload.apellidos is not None:
        estudiante.apellidos = payload.apellidos.strip()

    if payload.fecha_nacimiento is not None:
        estudiante.fecha_nacimiento = payload.fecha_nacimiento

    if payload.consentimiento_firmado is not None:
        estudiante.consentimiento_firmado = payload.consentimiento_firmado

        if not payload.consentimiento_firmado:
            estudiante.activo = False

    if payload.fecha_consentimiento is not None:
        estudiante.fecha_consentimiento = payload.fecha_consentimiento

    if estudiante.consentimiento_firmado and estudiante.fecha_consentimiento is None:
        raise HTTPException(
            status_code=400,
            detail="Debe registrar la fecha del consentimiento firmado.",
        )

    if payload.nivel_lectura is not None:
        estudiante.nivel_lectura = payload.nivel_lectura

    if payload.nivel_fonologia is not None:
        estudiante.nivel_fonologia = payload.nivel_fonologia

    if payload.activo is not None:
        if payload.activo and not estudiante.consentimiento_firmado:
            raise HTTPException(
                status_code=400,
                detail="No se puede activar un estudiante sin consentimiento firmado.",
            )

        estudiante.activo = payload.activo

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentAdminPublic.model_validate(estudiante)


@router.post(
    "/{estudiante_id}/regenerar-pin",
    response_model=StudentAdminPublic,
)
def regenerate_student_pin(
    estudiante_id: int,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentAdminPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    if estudiante.seccion_id is not None:
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=estudiante.seccion_id,
            session=session,
        )

    estudiante.pin_corto = _generate_pin_for_student(session)

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentAdminPublic.model_validate(estudiante)




def _get_active_jornada_for_section(
    seccion_id: int,
    session: Session,
) -> JornadaEvaluacion | None:
    now = datetime.utcnow()

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

    if jornada.fecha_expiracion is not None and jornada.fecha_expiracion <= now:
        jornada.estado = "EXPIRADA"
        jornada.fecha_cierre = now
        jornada.updated_at = now

        session.add(jornada)
        session.commit()

        return None

    return jornada


@router.get(
    "/modo-aula/{seccion_id}/pin/{pin_corto}",
    response_model=StudentPublic,
)
def get_estudiante_by_pin_for_modo_aula(
    seccion_id: int,
    pin_corto: str,
    session: Session = Depends(get_session),
) -> StudentPublic:
    _validate_pin(pin_corto)
    _ensure_section_exists(seccion_id, session)

    jornada = _get_active_jornada_for_section(
        seccion_id=seccion_id,
        session=session,
    )

    if jornada is None:
        raise HTTPException(
            status_code=403,
            detail="No hay jornada activa para esta secci?n.",
        )

    estudiante = session.exec(
        select(Estudiante).where(
            Estudiante.seccion_id == seccion_id,
            Estudiante.pin_corto == pin_corto,
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
    ).first()

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="No se encontr? estudiante activo con consentimiento firmado para esta secci?n y PIN.",
        )

    return StudentPublic.model_validate(estudiante)


@router.get("/pin/{pin_corto}", response_model=StudentPublic)
def get_estudiante_by_pin(
    pin_corto: str,
    session: Session = Depends(get_session),
) -> StudentPublic:
    _validate_pin(pin_corto)

    estudiante = session.exec(
        select(Estudiante).where(
            Estudiante.pin_corto == pin_corto,
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
    ).first()

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="No se encontró estudiante activo con consentimiento firmado para ese PIN.",
        )

    return StudentPublic.model_validate(estudiante)
