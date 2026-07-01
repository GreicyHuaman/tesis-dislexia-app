import hashlib
import hmac

import bcrypt


def hash_password(plain_password: str) -> str:
    password_bytes = plain_password.encode("utf-8")
    hashed = bcrypt.hashpw(password_bytes, bcrypt.gensalt())

    return hashed.decode("utf-8")


def verify_password(
    plain_password: str,
    stored_password_hash: str | None,
) -> bool:
    if not stored_password_hash:
        return False

    if _is_bcrypt_hash(stored_password_hash):
        try:
            return bcrypt.checkpw(
                plain_password.encode("utf-8"),
                stored_password_hash.encode("utf-8"),
            )
        except Exception:
            return False

    if _is_legacy_sha256_hash(stored_password_hash):
        legacy_hash = hashlib.sha256(
            plain_password.encode("utf-8")
        ).hexdigest()

        return hmac.compare_digest(
            legacy_hash,
            stored_password_hash,
        )

    return False


def password_needs_rehash(stored_password_hash: str | None) -> bool:
    if not stored_password_hash:
        return True

    return not _is_bcrypt_hash(stored_password_hash)


def _is_bcrypt_hash(value: str) -> bool:
    return (
        value.startswith("$2a$")
        or value.startswith("$2b$")
        or value.startswith("$2y$")
    )


def _is_legacy_sha256_hash(value: str) -> bool:
    if len(value) != 64:
        return False

    try:
        int(value, 16)
        return True
    except ValueError:
        return False

