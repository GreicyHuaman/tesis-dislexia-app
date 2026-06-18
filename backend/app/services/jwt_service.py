import os
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt


JWT_SECRET_KEY = os.getenv(
    "JWT_SECRET_KEY",
    "dev-secret-change-me-for-production",
)

JWT_ALGORITHM = os.getenv(
    "JWT_ALGORITHM",
    "HS256",
)

ACCESS_TOKEN_EXPIRE_MINUTES = int(
    os.getenv(
        "ACCESS_TOKEN_EXPIRE_MINUTES",
        "480",
    )
)


class JwtDecodeError(Exception):
    pass


def create_access_token(
    *,
    user_id: int,
    email: str,
    rol: str,
) -> str:
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    payload: dict[str, Any] = {
        "sub": str(user_id),
        "email": email,
        "rol": rol.upper(),
        "iat": int(now.timestamp()),
        "exp": expires_at,
        "type": "access",
    }

    return jwt.encode(
        payload,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM,
    )


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM],
        )

        if payload.get("type") != "access":
            raise JwtDecodeError("Token invalido.")

        return payload
    except jwt.ExpiredSignatureError as exc:
        raise JwtDecodeError("Token expirado.") from exc
    except jwt.InvalidTokenError as exc:
        raise JwtDecodeError("Token invalido.") from exc
