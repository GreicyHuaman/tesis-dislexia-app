from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.core.security import require_roles
from app.db.session import get_session
from app.models.student import Estudiante
from app.schemas.student_schema import (
    StudentCreate,
    StudentOfflineCacheItem,
    StudentPublic,
)

router = APIRouter(
    prefix="/api/v1/estudiantes",
    tags=["estudiantes"],
)


def _validate_pin(pin_corto: str) -> None:
    if len(pin_corto) != 4 or not pin_corto.isdigit():
        raise HTTPException(
            status_code=400,
            detail="El PIN debe tener exactamente 4 dígitos.",
        )


@router.post("", response_model=StudentPublic, dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))])
def create_estudiante(
    payload: StudentCreate,
    session: Session = Depends(get_session),
) -> StudentPublic:
    _validate_pin(payload.pin_corto)

    existing_student = session.exec(
        select(Estudiante).where(
            Estudiante.pin_corto == payload.pin_corto,
        )
    ).first()

    if existing_student is not None:
        raise HTTPException(
            status_code=400,
            detail="Ya existe un estudiante con ese PIN.",
        )

    estudiante = Estudiante(
        nombres=payload.nombres.strip(),
        apellidos=payload.apellidos.strip(),
        fecha_nacimiento=payload.fecha_nacimiento,
        pin_corto=payload.pin_corto,
        seccion_id=payload.seccion_id,
        activo=payload.activo,
    )

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentPublic.model_validate(estudiante)


@router.get("", response_model=list[StudentPublic], dependencies=[Depends(require_roles("MAESTRO", "PSICOLOGA", "DIRECTORA"))])
def list_estudiantes(
    session: Session = Depends(get_session),
) -> list[StudentPublic]:
    estudiantes = session.exec(
        select(Estudiante).order_by(Estudiante.id)
    ).all()

    return [
        StudentPublic.model_validate(estudiante)
        for estudiante in estudiantes
    ]


@router.get("/offline-cache", response_model=list[StudentOfflineCacheItem], dependencies=[Depends(require_roles("MAESTRO", "PSICOLOGA", "DIRECTORA"))])
def list_estudiantes_for_offline_cache(
    session: Session = Depends(get_session),
) -> list[StudentOfflineCacheItem]:
    estudiantes = session.exec(
        select(Estudiante)
        .where(Estudiante.activo == True)  # noqa: E712
        .order_by(Estudiante.id)
    ).all()

    result: list[StudentOfflineCacheItem] = []

    for estudiante in estudiantes:
        if estudiante.id is None:
            continue

        if not estudiante.pin_corto:
            continue

        result.append(
            StudentOfflineCacheItem(
                id=estudiante.id,
                nombres=estudiante.nombres,
                apellidos=estudiante.apellidos,
                fecha_nacimiento=estudiante.fecha_nacimiento,
                pin_corto=estudiante.pin_corto,
                seccion_id=estudiante.seccion_id,
                activo=estudiante.activo,
            )
        )

    return result


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
        )
    ).first()

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="No se encontró estudiante activo con ese PIN.",
        )

    return StudentPublic.model_validate(estudiante)

