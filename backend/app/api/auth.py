from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from app.db.session import get_session
from app.models.user import Usuario
from app.schemas.auth_schema import LoginRequest, LoginResponse
from app.services.password_service import verify_password

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["auth"],
)


@router.post("/login", response_model=LoginResponse)
def login(
    payload: LoginRequest,
    session: Session = Depends(get_session),
) -> LoginResponse:
    email = payload.email.strip().lower()

    usuario = session.exec(
        select(Usuario).where(
            Usuario.email == email,
            Usuario.activo == True,  # noqa: E712
        )
    ).first()

    if usuario is None:
        raise HTTPException(
            status_code=401,
            detail="Credenciales inválidas.",
        )

    if not verify_password(payload.password, usuario.password_hash):
        raise HTTPException(
            status_code=401,
            detail="Credenciales inválidas.",
        )

    return LoginResponse(
        id=usuario.id or 0,
        nombres=usuario.nombres,
        apellidos=usuario.apellidos,
        email=usuario.email,
        rol=usuario.rol,
        grado_scope=usuario.grado_scope,
    )
