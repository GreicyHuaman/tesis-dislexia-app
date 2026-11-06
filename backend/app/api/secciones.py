from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.core.security import get_current_user, require_roles
from app.db.session import get_session
from app.models.section import DocenteSeccion, Seccion
from app.models.user import Usuario
from app.schemas.section_schema import (
    SectionCreate,
    SectionPublic,
    SectionUpdate,
)

router = APIRouter(
    prefix="/api/v1/secciones",
    tags=["secciones"],
)


@router.get("", response_model=list[SectionPublic])
def list_secciones(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[SectionPublic]:
    rol = current_user.rol.upper()

    if rol == "MAESTRO":
        assigned_section_ids = select(DocenteSeccion.seccion_id).where(
            DocenteSeccion.usuario_id == current_user.id,
        )
        statement = (
            select(Seccion)
            .where(
                Seccion.activo == True,  # noqa: E712
                Seccion.id.in_(assigned_section_ids),
            )
            .order_by(Seccion.grado, Seccion.nombre)
        )
    else:
        statement = select(Seccion).order_by(Seccion.grado, Seccion.nombre)

    secciones = session.exec(statement).all()

    return [
        SectionPublic.model_validate(seccion)
        for seccion in secciones
    ]


@router.post(
    "",
    response_model=SectionPublic,
    dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))],
)
def create_seccion(
    payload: SectionCreate,
    session: Session = Depends(get_session),
) -> SectionPublic:
    nombre = payload.nombre.strip().upper()

    existing = session.exec(
        select(Seccion).where(
            Seccion.grado == payload.grado,
            Seccion.nombre == nombre,
        )
    ).first()

    if existing is not None:
        raise HTTPException(
            status_code=400,
            detail="Ya existe una sección con ese grado y nombre.",
        )

    seccion = Seccion(
        grado=payload.grado,
        nombre=nombre,
        turno=payload.turno,
        activo=payload.activo,
    )

    session.add(seccion)
    session.commit()
    session.refresh(seccion)

    return SectionPublic.model_validate(seccion)


@router.patch(
    "/{seccion_id}",
    response_model=SectionPublic,
    dependencies=[Depends(require_roles("PSICOLOGA", "DIRECTORA"))],
)
def update_seccion(
    seccion_id: int,
    payload: SectionUpdate,
    session: Session = Depends(get_session),
) -> SectionPublic:
    seccion = session.get(Seccion, seccion_id)

    if seccion is None:
        raise HTTPException(
            status_code=404,
            detail="Sección no encontrada.",
        )

    if payload.grado is not None:
        seccion.grado = payload.grado

    if payload.nombre is not None:
        seccion.nombre = payload.nombre.strip().upper()

    if payload.turno is not None:
        seccion.turno = payload.turno

    if payload.activo is not None:
        seccion.activo = payload.activo

    session.add(seccion)
    session.commit()
    session.refresh(seccion)

    return SectionPublic.model_validate(seccion)
