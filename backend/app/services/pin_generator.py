from __future__ import annotations

import random


BLOCKED_PINS = {
    "1234",
    "4321",
    "9876",
    "6789",
    "2580",
    "0123",
    "2345",
    "3456",
    "4567",
    "5678",
    "7890",
    "3210",
    "5432",
    "6543",
    "7654",
    "8765",
}


class PinValidationError(ValueError):
    pass


def validate_pin_rules(pin: str) -> None:
    if len(pin) != 4 or not pin.isdigit():
        raise PinValidationError("El PIN debe tener exactamente 4 dígitos.")

    if pin.startswith("0"):
        raise PinValidationError("El PIN no puede iniciar con 0.")

    if len(set(pin)) != 4:
        raise PinValidationError("El PIN no puede repetir dígitos.")

    if pin in BLOCKED_PINS:
        raise PinValidationError("El PIN pertenece a un patrón demasiado obvio.")


def is_valid_pin(pin: str) -> bool:
    try:
        validate_pin_rules(pin)
        return True
    except PinValidationError:
        return False


def generate_unique_pin(existing_pins: set[str]) -> str:
    candidates: list[str] = []

    for value in range(1000, 10000):
        pin = str(value)

        if pin in existing_pins:
            continue

        if is_valid_pin(pin):
            candidates.append(pin)

    if not candidates:
        raise RuntimeError("No hay PINs disponibles con las reglas actuales.")

    return random.SystemRandom().choice(candidates)
