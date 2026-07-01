from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.core.security import require_roles
from app.db.session import get_session
from app.models.section import DocenteSeccion, Seccion
from app.models.user import Usuario
from app.schemas.teacher_section_schema import (
    TeacherSectionCreate,
    TeacherSectionPublic,
)

router = APIRouter(
    prefix="/api/v1/admin/docente-seccion",
    tags=["admin-docente-seccion"],
)


@router.get(
    "",
    response_model=list[TeacherSectionPublic],
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def list_docente_seccion(
    session: Session = Depends(get_session),
) -> list[TeacherSectionPublic]:
    links = session.exec(
        select(DocenteSeccion).order_by(DocenteSeccion.usuario_id)
    ).all()

    return [
        TeacherSectionPublic.model_validate(link)
        for link in links
    ]


@router.post(
    "",
    response_model=TeacherSectionPublic,
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def create_docente_seccion(
    payload: TeacherSectionCreate,
    session: Session = Depends(get_session),
) -> TeacherSectionPublic:
    usuario = session.get(Usuario, payload.usuario_id)

    if usuario is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado.",
        )

    if usuario.rol.upper() != "MAESTRO":
        raise HTTPException(
            status_code=400,
            detail="Solo usuarios con rol MAESTRO pueden asignarse a secciones.",
        )

    seccion = session.get(Seccion, payload.seccion_id)

    if seccion is None:
        raise HTTPException(
            status_code=404,
            detail="Sección no encontrada.",
        )

    existing = session.exec(
        select(DocenteSeccion).where(
            DocenteSeccion.usuario_id == payload.usuario_id,
            DocenteSeccion.seccion_id == payload.seccion_id,
        )
    ).first()

    if existing is not None:
        return TeacherSectionPublic.model_validate(existing)

    link = DocenteSeccion(
        usuario_id=payload.usuario_id,
        seccion_id=payload.seccion_id,
    )

    session.add(link)
    session.commit()
    session.refresh(link)

    return TeacherSectionPublic.model_validate(link)


@router.delete(
    "/{link_id}",
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def delete_docente_seccion(
    link_id: int,
    session: Session = Depends(get_session),
):
    link = session.get(DocenteSeccion, link_id)

    if link is None:
        raise HTTPException(
            status_code=404,
            detail="Asignación no encontrada.",
        )

    session.delete(link)
    session.commit()

    return {
        "status": "ok",
        "deleted_id": link_id,
    }

