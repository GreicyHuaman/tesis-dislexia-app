from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.core.security import get_current_user
from app.db.session import get_session
from app.models.user import Usuario
from app.schemas.auth_schema import (
    CurrentUserPublic,
    LoginRequest,
    LoginResponse,
)
from app.services.jwt_service import (
    create_access_token,
    get_access_token_expire_minutes,
)
from app.services.password_service import (
    hash_password,
    password_needs_rehash,
    verify_password,
)

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["auth"],
)


def _build_login_response(
    user: Usuario,
    access_token: str,
) -> LoginResponse:
    public_user = CurrentUserPublic.model_validate(user)

    return LoginResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in_minutes=get_access_token_expire_minutes(),
        user=public_user,
        id=public_user.id,
        nombres=public_user.nombres,
        apellidos=public_user.apellidos,
        email=public_user.email,
        rol=public_user.rol,
        grado_scope=public_user.grado_scope,
        activo=public_user.activo,
    )


@router.post("/login", response_model=LoginResponse)
def login(
    payload: LoginRequest,
    session: Session = Depends(get_session),
) -> LoginResponse:
    email = payload.email.strip().lower()

    user = session.exec(
        select(Usuario).where(
            Usuario.email == email,
            Usuario.activo == True,  # noqa: E712
        )
    ).first()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales invalidas.",
        )

    password_ok = verify_password(
        plain_password=payload.password,
        stored_password_hash=user.password_hash,
    )

    if not password_ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales invalidas.",
        )

    if password_needs_rehash(user.password_hash):
        user.password_hash = hash_password(payload.password)
        session.add(user)
        session.commit()
        session.refresh(user)

    access_token = create_access_token(
        user_id=user.id or 0,
        email=user.email,
        rol=user.rol,
    )

    return _build_login_response(
        user=user,
        access_token=access_token,
    )


@router.get("/me", response_model=CurrentUserPublic)
def get_me(
    current_user: Usuario = Depends(get_current_user),
) -> CurrentUserPublic:
    return CurrentUserPublic.model_validate(current_user)
