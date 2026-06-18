import hashlib


def hash_password(password: str) -> str:
    normalized = password.strip()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def verify_password(password: str, password_hash: str) -> bool:
    return hash_password(password) == password_hash
