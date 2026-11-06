import os
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt


def _jwt_configuration() -> tuple[str, str, int]:
    secret = os.getenv("JWT_SECRET_KEY", "").strip()
    algorithm = os.getenv("JWT_ALGORITHM", "HS256")
    if len(secret.encode("utf-8")) < 32:
        raise RuntimeError("JWT_SECRET_KEY es obligatoria y debe tener al menos 32 bytes.")
    if algorithm not in {"HS256", "HS384", "HS512"}:
        raise RuntimeError("JWT_ALGORITHM debe ser HS256, HS384 o HS512.")
    minimum_bytes = {"HS256": 32, "HS384": 48, "HS512": 64}[algorithm]
    if len(secret.encode("utf-8")) < minimum_bytes:
        raise RuntimeError("JWT_SECRET_KEY no tiene la longitud requerida por JWT_ALGORITHM.")
    try:
        minutes = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "480"))
    except ValueError as error:
        raise RuntimeError("ACCESS_TOKEN_EXPIRE_MINUTES debe ser un entero positivo.") from error
    if minutes <= 0:
        raise RuntimeError("ACCESS_TOKEN_EXPIRE_MINUTES debe ser un entero positivo.")
    return secret, algorithm, minutes


def validate_jwt_configuration() -> None:
    _jwt_configuration()


def get_access_token_expire_minutes() -> int:
    return _jwt_configuration()[2]


class JwtDecodeError(Exception):
    pass


def create_access_token(*, user_id: int, email: str, rol: str) -> str:
    secret, algorithm, minutes = _jwt_configuration()
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "email": email,
        "rol": rol.upper(),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=minutes)).timestamp()),
        "type": "access",
    }
    return jwt.encode(payload, secret, algorithm=algorithm)


def decode_access_token(token: str) -> dict[str, Any]:
    secret, algorithm, _ = _jwt_configuration()
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=[algorithm],
            options={"require": ["sub", "iat", "exp", "type"]},
        )
        if payload.get("type") != "access":
            raise JwtDecodeError("Token invalido.")
        return payload
    except jwt.ExpiredSignatureError as error:
        raise JwtDecodeError("Token expirado.") from error
    except jwt.InvalidTokenError as error:
        raise JwtDecodeError("Token invalido.") from error
