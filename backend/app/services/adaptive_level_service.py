from dataclasses import dataclass

from sqlmodel import Session, select

from app.models.evaluation import Evaluacion
from app.models.student import Estudiante


MIN_ADAPTIVE_LEVEL = 1
MAX_ADAPTIVE_LEVEL = 3


@dataclass
class AdaptiveLevelResult:
    tipo_prueba: str
    nivel_anterior: int
    nivel_actualizado: int
    nivel_lectura: int
    nivel_fonologia: int
    cambio_nivel: str


def update_student_level_for_test_type(
    *,
    session: Session,
    estudiante_id: int | None,
    tipo_prueba: str | None,
) -> AdaptiveLevelResult | None:
    if estudiante_id is None:
        return None

    normalized_tipo = _normalize_tipo_prueba(tipo_prueba)

    if normalized_tipo is None:
        return None

    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        return None

    current_level = _get_current_level(estudiante, normalized_tipo)
    recalculated_level = _recalculate_level_from_history(
        session=session,
        estudiante_id=estudiante_id,
        tipo_prueba=normalized_tipo,
    )

    _set_current_level(
        estudiante=estudiante,
        tipo_prueba=normalized_tipo,
        level=recalculated_level,
    )

    session.add(estudiante)

    return AdaptiveLevelResult(
        tipo_prueba=normalized_tipo,
        nivel_anterior=current_level,
        nivel_actualizado=recalculated_level,
        nivel_lectura=_clamp_level(estudiante.nivel_lectura),
        nivel_fonologia=_clamp_level(estudiante.nivel_fonologia),
        cambio_nivel=_build_change_label(
            previous_level=current_level,
            new_level=recalculated_level,
        ),
    )


def _normalize_tipo_prueba(tipo_prueba: str | None) -> str | None:
    normalized = (tipo_prueba or "").strip().upper()

    if normalized in {"LECTURA", "FONOLOGIA"}:
        return normalized

    return None


def _get_current_level(estudiante: Estudiante, tipo_prueba: str) -> int:
    if tipo_prueba == "LECTURA":
        return _clamp_level(estudiante.nivel_lectura)

    return _clamp_level(estudiante.nivel_fonologia)


def _set_current_level(
    *,
    estudiante: Estudiante,
    tipo_prueba: str,
    level: int,
) -> None:
    clamped_level = _clamp_level(level)

    if tipo_prueba == "LECTURA":
        estudiante.nivel_lectura = clamped_level
        return

    estudiante.nivel_fonologia = clamped_level


def _recalculate_level_from_history(
    *,
    session: Session,
    estudiante_id: int,
    tipo_prueba: str,
) -> int:
    evaluaciones = session.exec(
        select(Evaluacion)
        .where(
            Evaluacion.estudiante_id == estudiante_id,
            Evaluacion.tipo_prueba == tipo_prueba,
        )
        .order_by(
            Evaluacion.fecha_evaluacion,
            Evaluacion.id,
        )
    ).all()

    level = MIN_ADAPTIVE_LEVEL
    consecutive_green = 0

    for evaluacion in evaluaciones:
        semaforo = (evaluacion.semaforo or "").strip().upper()

        if semaforo == "VERDE":
            consecutive_green += 1

            if consecutive_green >= 2 and level < MAX_ADAPTIVE_LEVEL:
                level += 1
                consecutive_green = 0

            continue

        consecutive_green = 0

        if semaforo == "ROJO" and level > MIN_ADAPTIVE_LEVEL:
            level -= 1

    return _clamp_level(level)


def _clamp_level(level: int | None) -> int:
    if level is None:
        return MIN_ADAPTIVE_LEVEL

    return max(MIN_ADAPTIVE_LEVEL, min(MAX_ADAPTIVE_LEVEL, int(level)))


def _build_change_label(
    *,
    previous_level: int,
    new_level: int,
) -> str:
    if new_level > previous_level:
        return "SUBE"

    if new_level < previous_level:
        return "BAJA"

    return "MANTIENE"
