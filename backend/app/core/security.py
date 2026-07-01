from collections.abc import Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlmodel import Session

from app.db.session import get_session
from app.models.user import Usuario
from app.services.jwt_service import JwtDecodeError, decode_access_token


oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/v1/auth/login",
)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    session: Session = Depends(get_session),
) -> Usuario:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No autenticado o token invalido.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = decode_access_token(token)
        user_id_raw = payload.get("sub")

        if user_id_raw is None:
            raise credentials_exception

        user_id = int(user_id_raw)
    except (JwtDecodeError, ValueError):
        raise credentials_exception

    user = session.get(Usuario, user_id)

    if user is None or not user.activo:
        raise credentials_exception

    return user


def require_roles(*allowed_roles: str) -> Callable:
    normalized_allowed_roles = {
        role.upper()
        for role in allowed_roles
    }

    def dependency(
        current_user: Usuario = Depends(get_current_user),
    ) -> Usuario:
        user_role = current_user.rol.upper()

        if user_role not in normalized_allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para esta operacion.",
            )

        return current_user

    return dependency

