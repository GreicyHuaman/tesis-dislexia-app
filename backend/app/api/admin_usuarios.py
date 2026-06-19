from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.core.security import require_roles
from app.db.session import get_session
from app.models.user import Usuario
from app.schemas.admin_user_schema import (
    AdminUserCreate,
    AdminUserPublic,
    AdminUserUpdate,
)
from app.services.password_service import hash_password

router = APIRouter(
    prefix="/api/v1/admin/usuarios",
    tags=["admin-usuarios"],
)

ALLOWED_ROLES = {
    "MAESTRO",
    "PSICOLOGA",
    "DIRECTORA",
}


def _normalize_role(role: str) -> str:
    normalized = role.strip().upper()

    if normalized not in ALLOWED_ROLES:
        raise HTTPException(
            status_code=400,
            detail="Rol inválido. Usa MAESTRO, PSICOLOGA o DIRECTORA.",
        )

    return normalized


@router.get(
    "",
    response_model=list[AdminUserPublic],
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def list_admin_users(
    session: Session = Depends(get_session),
) -> list[AdminUserPublic]:
    users = session.exec(
        select(Usuario).order_by(Usuario.rol, Usuario.apellidos, Usuario.nombres)
    ).all()

    return [
        AdminUserPublic.model_validate(user)
        for user in users
    ]


@router.post(
    "",
    response_model=AdminUserPublic,
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def create_admin_user(
    payload: AdminUserCreate,
    session: Session = Depends(get_session),
) -> AdminUserPublic:
    email = payload.email.strip().lower()
    rol = _normalize_role(payload.rol)

    existing = session.exec(
        select(Usuario).where(
            Usuario.email == email,
        )
    ).first()

    if existing is not None:
        raise HTTPException(
            status_code=400,
            detail="Ya existe un usuario con ese correo.",
        )

    if len(payload.password) < 6:
        raise HTTPException(
            status_code=400,
            detail="La contraseña debe tener al menos 6 caracteres.",
        )

    user = Usuario(
        nombres=payload.nombres.strip(),
        apellidos=payload.apellidos.strip(),
        email=email,
        rol=rol,
        password_hash=hash_password(payload.password),
        grado_scope=payload.grado_scope,
        activo=payload.activo,
    )

    session.add(user)
    session.commit()
    session.refresh(user)

    return AdminUserPublic.model_validate(user)


@router.patch(
    "/{usuario_id}",
    response_model=AdminUserPublic,
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def update_admin_user(
    usuario_id: int,
    payload: AdminUserUpdate,
    session: Session = Depends(get_session),
) -> AdminUserPublic:
    user = session.get(Usuario, usuario_id)

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado.",
        )

    if payload.nombres is not None:
        user.nombres = payload.nombres.strip()

    if payload.apellidos is not None:
        user.apellidos = payload.apellidos.strip()

    if payload.email is not None:
        email = payload.email.strip().lower()

        existing = session.exec(
            select(Usuario).where(
                Usuario.email == email,
                Usuario.id != usuario_id,
            )
        ).first()

        if existing is not None:
            raise HTTPException(
                status_code=400,
                detail="Ya existe otro usuario con ese correo.",
            )

        user.email = email

    if payload.rol is not None:
        user.rol = _normalize_role(payload.rol)

    if payload.password is not None:
        if len(payload.password) < 6:
            raise HTTPException(
                status_code=400,
                detail="La contraseña debe tener al menos 6 caracteres.",
            )

        user.password_hash = hash_password(payload.password)

    if payload.grado_scope is not None:
        user.grado_scope = payload.grado_scope

    if payload.activo is not None:
        user.activo = payload.activo

    session.add(user)
    session.commit()
    session.refresh(user)

    return AdminUserPublic.model_validate(user)
