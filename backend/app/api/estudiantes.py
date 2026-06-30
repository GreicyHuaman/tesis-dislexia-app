import csv
import io
import re
import unicodedata
from datetime import date, datetime

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlmodel import Session, select

from app.core.security import get_current_user
from app.db.session import get_session
from app.models.jornada import JornadaEvaluacion
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.student_import_schema import StudentImportResponse, StudentImportRowResult
from app.schemas.student_schema import (
    StudentAdminPublic,
    StudentCreate,
    StudentOfflineCacheItem,
    StudentPublic,
    StudentUpdate,
)
from app.services.pin_generator import (
    PinValidationError,
    generate_unique_pin,
    validate_pin_rules,
)

router = APIRouter(
    prefix="/api/v1/estudiantes",
    tags=["estudiantes"],
)


def _raise_forbidden() -> None:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="No tienes permisos para esta operación.",
    )


def _validate_pin(pin_corto: str) -> None:
    try:
        validate_pin_rules(pin_corto)
    except PinValidationError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc


def _get_docente_section_ids(
    usuario: Usuario,
    session: Session,
) -> set[int]:
    if usuario.id is None:
        return set()

    links = session.exec(
        select(DocenteSeccion).where(
            DocenteSeccion.usuario_id == usuario.id,
        )
    ).all()

    return {
        link.seccion_id
        for link in links
    }


def _get_allowed_section_ids_for_user(
    usuario: Usuario,
    session: Session,
) -> set[int] | None:
    rol = usuario.rol.upper()

    if rol == "MAESTRO":
        return _get_docente_section_ids(usuario, session)

    if rol in {"DIRECTORA", "PSICOLOGA"}:
        return None

    return set()


def _ensure_section_exists(seccion_id: int, session: Session) -> Seccion:
    seccion = session.get(Seccion, seccion_id)

    if seccion is None:
        raise HTTPException(
            status_code=404,
            detail="Sección no encontrada.",
        )

    if not seccion.activo:
        raise HTTPException(
            status_code=400,
            detail="La sección no está activa.",
        )

    return seccion


def _ensure_user_can_manage_section(
    usuario: Usuario,
    seccion_id: int,
    session: Session,
) -> None:
    rol = usuario.rol.upper()

    _ensure_section_exists(seccion_id, session)

    if rol == "DIRECTORA":
        return

    if rol == "MAESTRO":
        allowed_ids = _get_docente_section_ids(usuario, session)

        if seccion_id in allowed_ids:
            return

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El docente solo puede gestionar estudiantes de sus secciones asignadas.",
        )

    _raise_forbidden()


def _validate_consentimiento(payload: StudentCreate | StudentUpdate) -> None:
    consentimiento = getattr(payload, "consentimiento_firmado", None)
    fecha = getattr(payload, "fecha_consentimiento", None)

    if consentimiento is False:
        raise HTTPException(
            status_code=400,
            detail="Solo se puede activar estudiantes con consentimiento firmado.",
        )

    if consentimiento is True and fecha is None:
        raise HTTPException(
            status_code=400,
            detail="Debe registrar la fecha del consentimiento firmado.",
        )


def _get_existing_active_pins(
    session: Session,
    exclude_student_id: int | None = None,
) -> set[str]:
    statement = select(Estudiante).where(
        Estudiante.activo == True,  # noqa: E712
    )

    if exclude_student_id is not None:
        statement = statement.where(Estudiante.id != exclude_student_id)

    estudiantes = session.exec(statement).all()

    return {
        estudiante.pin_corto
        for estudiante in estudiantes
        if estudiante.pin_corto
    }


def _ensure_pin_is_unique(
    pin_corto: str,
    session: Session,
    exclude_student_id: int | None = None,
) -> None:
    statement = select(Estudiante).where(
        Estudiante.pin_corto == pin_corto,
        Estudiante.activo == True,  # noqa: E712
    )

    if exclude_student_id is not None:
        statement = statement.where(Estudiante.id != exclude_student_id)

    existing_student = session.exec(statement).first()

    if existing_student is not None:
        raise HTTPException(
            status_code=400,
            detail="Ya existe un estudiante activo con ese PIN.",
        )


def _generate_pin_for_student(
    session: Session,
    exclude_student_id: int | None = None,
) -> str:
    existing_pins = _get_existing_active_pins(
        session=session,
        exclude_student_id=exclude_student_id,
    )

    return generate_unique_pin(existing_pins)


def _apply_student_filters_for_user(
    statement,
    usuario: Usuario,
    session: Session,
):
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=usuario,
        session=session,
    )

    if allowed_section_ids is None:
        return statement

    if not allowed_section_ids:
        return None

    return statement.where(
        Estudiante.seccion_id.in_(list(allowed_section_ids)),
    )


_REQUIRED_IMPORT_COLUMNS = {
    "nombres",
    "apellidos",
    "fecha_nacimiento",
    "grado",
    "seccion",
    "consentimiento_firmado",
    "fecha_consentimiento",
    "activo",
}

_TRUE_VALUES = {"1", "true", "si", "s?", "s", "x", "yes", "y", "firmado"}
_FALSE_VALUES = {"0", "false", "no", "n", ""}


def _normalize_import_key(value: object) -> str:
    text = "" if value is None else str(value)
    text = text.strip().lower()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(char for char in text if not unicodedata.combining(char))
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = text.strip("_")

    aliases = {
        "codigo": "codigo_estudiante",
        "cod_estudiante": "codigo_estudiante",
        "codigo_alumno": "codigo_estudiante",
        "fecha_nac": "fecha_nacimiento",
        "nacimiento": "fecha_nacimiento",
        "seccion_nombre": "seccion",
        "secci?n": "seccion",
        "consentimiento": "consentimiento_firmado",
        "consentimiento_apoderado": "consentimiento_firmado",
        "fecha_consent": "fecha_consentimiento",
        "estado": "activo",
    }

    return aliases.get(text, text)


def _normalize_import_row(row: dict[object, object]) -> dict[str, object]:
    return {
        _normalize_import_key(key): value
        for key, value in row.items()
    }


def _validate_import_headers(headers: set[str]) -> None:
    missing = sorted(_REQUIRED_IMPORT_COLUMNS - headers)

    if missing:
        raise HTTPException(
            status_code=400,
            detail=f"Faltan columnas obligatorias: {', '.join(missing)}",
        )


def _clean_optional_text(value: object) -> str | None:
    if value is None:
        return None

    text = str(value).strip()

    if not text:
        return None

    return text


def _required_text(
    row: dict[str, object],
    key: str,
    row_number: int,
) -> str:
    value = _clean_optional_text(row.get(key))

    if value is None:
        raise ValueError(f"Fila {row_number}: falta el campo {key}.")

    return value


def _parse_import_bool(
    value: object,
    *,
    default: bool,
    field_name: str,
    row_number: int,
) -> bool:
    if value is None:
        return default

    if isinstance(value, bool):
        return value

    if isinstance(value, (int, float)):
        return value != 0

    text = str(value).strip().lower()

    if text in _TRUE_VALUES:
        return True

    if text in _FALSE_VALUES:
        return False

    raise ValueError(
        f"Fila {row_number}: valor invalido para {field_name}. Use SI/NO."
    )


def _parse_import_int(
    value: object,
    *,
    field_name: str,
    row_number: int,
) -> int:
    if value is None:
        raise ValueError(f"Fila {row_number}: falta el campo {field_name}.")

    if isinstance(value, int):
        return value

    if isinstance(value, float):
        return int(value)

    text = str(value).strip()

    if not text:
        raise ValueError(f"Fila {row_number}: falta el campo {field_name}.")

    try:
        return int(float(text))
    except ValueError as exc:
        raise ValueError(
            f"Fila {row_number}: {field_name} debe ser numerico."
        ) from exc


def _parse_import_date(
    value: object,
    *,
    field_name: str,
    row_number: int,
) -> date | None:
    if value is None:
        return None

    if isinstance(value, datetime):
        return value.date()

    if isinstance(value, date):
        return value

    text = str(value).strip()

    if not text:
        return None

    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue

    raise ValueError(
        f"Fila {row_number}: {field_name} debe tener formato YYYY-MM-DD."
    )


def _find_section_for_import(
    *,
    grado: int,
    seccion_nombre: str,
    session: Session,
) -> Seccion | None:
    nombre = seccion_nombre.strip().upper()

    seccion = session.exec(
        select(Seccion).where(
            Seccion.grado == grado,
            Seccion.nombre == nombre,
            Seccion.activo == True,  # noqa: E712
        )
    ).first()

    if seccion is not None:
        return seccion

    # Soporta casos como "3A" cuando en BD la seccion esta como "A".
    if nombre.startswith(str(grado)):
        nombre_sin_grado = nombre[len(str(grado)):].strip()

        if nombre_sin_grado:
            return session.exec(
                select(Seccion).where(
                    Seccion.grado == grado,
                    Seccion.nombre == nombre_sin_grado,
                    Seccion.activo == True,  # noqa: E712
                )
            ).first()

    return None


def _find_existing_student_for_import(
    *,
    codigo_estudiante: str | None,
    nombres: str,
    apellidos: str,
    seccion_id: int,
    session: Session,
) -> Estudiante | None:
    if codigo_estudiante:
        existing = session.exec(
            select(Estudiante).where(
                Estudiante.codigo_estudiante == codigo_estudiante,
            )
        ).first()

        if existing is not None:
            return existing

    candidates = session.exec(
        select(Estudiante).where(
            Estudiante.seccion_id == seccion_id,
        )
    ).all()

    nombres_norm = nombres.strip().lower()
    apellidos_norm = apellidos.strip().lower()

    for candidate in candidates:
        if (
            candidate.nombres.strip().lower() == nombres_norm
            and candidate.apellidos.strip().lower() == apellidos_norm
        ):
            return candidate

    return None


async def _read_student_import_rows(
    file: UploadFile,
) -> list[tuple[int, dict[str, object]]]:
    filename = (file.filename or "").lower()
    contents = await file.read()

    if not contents:
        raise HTTPException(
            status_code=400,
            detail="El archivo esta vacio.",
        )

    if filename.endswith(".csv"):
        try:
            text = contents.decode("utf-8-sig")
        except UnicodeDecodeError:
            text = contents.decode("latin-1")

        reader = csv.DictReader(io.StringIO(text))

        if reader.fieldnames is None:
            raise HTTPException(
                status_code=400,
                detail="El CSV no tiene encabezados.",
            )

        headers = {
            _normalize_import_key(header)
            for header in reader.fieldnames
        }
        _validate_import_headers(headers)

        rows: list[tuple[int, dict[str, object]]] = []

        for row_number, row in enumerate(reader, start=2):
            normalized = _normalize_import_row(row)

            if all(
                _clean_optional_text(value) is None
                for value in normalized.values()
            ):
                continue

            rows.append((row_number, normalized))

        return rows

    if filename.endswith(".xlsx"):
        try:
            from openpyxl import load_workbook
        except ImportError as exc:
            raise HTTPException(
                status_code=500,
                detail="Falta instalar openpyxl para leer archivos XLSX.",
            ) from exc

        workbook = load_workbook(io.BytesIO(contents), read_only=True, data_only=True)
        sheet = workbook.active

        raw_headers = [
            cell.value
            for cell in next(sheet.iter_rows(min_row=1, max_row=1))
        ]

        headers = [
            _normalize_import_key(header)
            for header in raw_headers
        ]

        _validate_import_headers(set(headers))

        rows = []

        for row_number, excel_row in enumerate(
            sheet.iter_rows(min_row=2, values_only=True),
            start=2,
        ):
            raw_values = list(excel_row)

            if all(_clean_optional_text(value) is None for value in raw_values):
                continue

            normalized = {
                headers[index]: raw_values[index]
                for index in range(min(len(headers), len(raw_values)))
            }

            rows.append((row_number, normalized))

        return rows

    raise HTTPException(
        status_code=400,
        detail="Formato no soportado. Use CSV o XLSX.",
    )


def _apply_import_to_student(
    *,
    estudiante: Estudiante,
    codigo_estudiante: str | None,
    nombres: str,
    apellidos: str,
    fecha_nacimiento: date | None,
    seccion_id: int,
    consentimiento_firmado: bool,
    fecha_consentimiento: date | None,
    activo: bool,
    session: Session,
) -> None:
    estudiante.codigo_estudiante = codigo_estudiante
    estudiante.nombres = nombres.strip()
    estudiante.apellidos = apellidos.strip()
    estudiante.fecha_nacimiento = fecha_nacimiento
    estudiante.seccion_id = seccion_id
    estudiante.consentimiento_firmado = consentimiento_firmado
    estudiante.fecha_consentimiento = (
        fecha_consentimiento
        if consentimiento_firmado
        else None
    )
    estudiante.activo = activo and consentimiento_firmado

    if not consentimiento_firmado:
        estudiante.pin_corto = None
        return

    if estudiante.pin_corto:
        _ensure_pin_is_unique(
            pin_corto=estudiante.pin_corto,
            session=session,
            exclude_student_id=estudiante.id,
        )
    else:
        estudiante.pin_corto = _generate_pin_for_student(
            session=session,
            exclude_student_id=estudiante.id,
        )



@router.post(
    "",
    response_model=StudentAdminPublic,
)
def create_estudiante(
    payload: StudentCreate,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentAdminPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    _ensure_user_can_manage_section(
        usuario=current_user,
        seccion_id=payload.seccion_id,
        session=session,
    )

    _validate_consentimiento(payload)

    if payload.pin_corto:
        _validate_pin(payload.pin_corto)
        _ensure_pin_is_unique(payload.pin_corto, session)
        pin_corto = payload.pin_corto
    else:
        pin_corto = _generate_pin_for_student(session)

    estudiante = Estudiante(
        codigo_estudiante=(
            payload.codigo_estudiante.strip()
            if payload.codigo_estudiante
            else None
        ),
        nombres=payload.nombres.strip(),
        apellidos=payload.apellidos.strip(),
        fecha_nacimiento=payload.fecha_nacimiento,
        pin_corto=pin_corto,
        seccion_id=payload.seccion_id,
        consentimiento_firmado=payload.consentimiento_firmado,
        fecha_consentimiento=payload.fecha_consentimiento,
        nivel_lectura=1,
        nivel_fonologia=1,
        activo=payload.activo,
    )

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentAdminPublic.model_validate(estudiante)


@router.get(
    "",
    response_model=list[StudentPublic],
)
def list_estudiantes(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[StudentPublic]:
    if current_user.rol.upper() not in {"MAESTRO", "PSICOLOGA", "DIRECTORA"}:
        _raise_forbidden()

    statement = select(Estudiante).order_by(
        Estudiante.apellidos,
        Estudiante.nombres,
    )

    statement = _apply_student_filters_for_user(
        statement=statement,
        usuario=current_user,
        session=session,
    )

    if statement is None:
        return []

    estudiantes = session.exec(statement).all()

    return [
        StudentPublic.model_validate(estudiante)
        for estudiante in estudiantes
    ]


@router.get(
    "/admin/list",
    response_model=list[StudentAdminPublic],
)
def list_estudiantes_admin(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[StudentAdminPublic]:
    if current_user.rol.upper() not in {"MAESTRO", "PSICOLOGA", "DIRECTORA"}:
        _raise_forbidden()

    statement = select(Estudiante).order_by(
        Estudiante.apellidos,
        Estudiante.nombres,
    )

    statement = _apply_student_filters_for_user(
        statement=statement,
        usuario=current_user,
        session=session,
    )

    if statement is None:
        return []

    estudiantes = session.exec(statement).all()

    return [
        StudentAdminPublic.model_validate(estudiante)
        for estudiante in estudiantes
    ]


@router.get(
    "/offline-cache",
    response_model=list[StudentOfflineCacheItem],
)
def list_estudiantes_for_offline_cache(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[StudentOfflineCacheItem]:
    if current_user.rol.upper() not in {"MAESTRO", "PSICOLOGA", "DIRECTORA"}:
        _raise_forbidden()

    statement = (
        select(Estudiante)
        .where(
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
        .order_by(Estudiante.id)
    )

    statement = _apply_student_filters_for_user(
        statement=statement,
        usuario=current_user,
        session=session,
    )

    if statement is None:
        return []

    estudiantes = session.exec(statement).all()

    result: list[StudentOfflineCacheItem] = []

    for estudiante in estudiantes:
        if estudiante.id is None:
            continue

        if not estudiante.pin_corto:
            continue

        result.append(
            StudentOfflineCacheItem(
                id=estudiante.id,
                codigo_estudiante=estudiante.codigo_estudiante,
                nombres=estudiante.nombres,
                apellidos=estudiante.apellidos,
                fecha_nacimiento=estudiante.fecha_nacimiento,
                pin_corto=estudiante.pin_corto,
                seccion_id=estudiante.seccion_id,
                consentimiento_firmado=estudiante.consentimiento_firmado,
                nivel_lectura=estudiante.nivel_lectura,
                nivel_fonologia=estudiante.nivel_fonologia,
                activo=estudiante.activo,
            )
        )

    return result


@router.post(
    "/importar",
    response_model=StudentImportResponse,
)
async def import_estudiantes(
    file: UploadFile = File(...),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentImportResponse:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    rows = await _read_student_import_rows(file)

    created_count = 0
    updated_count = 0
    skipped_count = 0
    error_count = 0
    results: list[StudentImportRowResult] = []

    for row_number, row in rows:
        try:
            codigo_estudiante = None
            nombres = _required_text(row, "nombres", row_number)
            apellidos = _required_text(row, "apellidos", row_number)
            fecha_nacimiento = _parse_import_date(
                row.get("fecha_nacimiento"),
                field_name="fecha_nacimiento",
                row_number=row_number,
            )
            grado = _parse_import_int(
                row.get("grado"),
                field_name="grado",
                row_number=row_number,
            )
            seccion_nombre = _required_text(row, "seccion", row_number)

            consentimiento_firmado = _parse_import_bool(
                row.get("consentimiento_firmado"),
                default=False,
                field_name="consentimiento_firmado",
                row_number=row_number,
            )
            fecha_consentimiento = _parse_import_date(
                row.get("fecha_consentimiento"),
                field_name="fecha_consentimiento",
                row_number=row_number,
            )
            activo = _parse_import_bool(
                row.get("activo"),
                default=True,
                field_name="activo",
                row_number=row_number,
            )

            if consentimiento_firmado and fecha_consentimiento is None:
                raise ValueError(
                    f"Fila {row_number}: debe registrar fecha_consentimiento."
                )

            seccion = _find_section_for_import(
                grado=grado,
                seccion_nombre=seccion_nombre,
                session=session,
            )

            if seccion is None or seccion.id is None:
                raise ValueError(
                    f"Fila {row_number}: no existe seccion activa "
                    f"para grado={grado}, seccion={seccion_nombre}."
                )

            _ensure_user_can_manage_section(
                usuario=current_user,
                seccion_id=seccion.id,
                session=session,
            )

            existing = _find_existing_student_for_import(
                codigo_estudiante=codigo_estudiante,
                nombres=nombres,
                apellidos=apellidos,
                seccion_id=seccion.id,
                session=session,
            )

            if existing is not None:
                if existing.seccion_id is not None:
                    _ensure_user_can_manage_section(
                        usuario=current_user,
                        seccion_id=existing.seccion_id,
                        session=session,
                    )

                _apply_import_to_student(
                    estudiante=existing,
                    codigo_estudiante=codigo_estudiante,
                    nombres=nombres,
                    apellidos=apellidos,
                    fecha_nacimiento=fecha_nacimiento,
                    seccion_id=seccion.id,
                    consentimiento_firmado=consentimiento_firmado,
                    fecha_consentimiento=fecha_consentimiento,
                    activo=activo,
                    session=session,
                )

                session.add(existing)
                session.commit()
                session.refresh(existing)

                updated_count += 1

                results.append(
                    StudentImportRowResult(
                        row_number=row_number,
                        status="updated",
                        message="Estudiante actualizado.",
                        estudiante_id=existing.id,
                        codigo_estudiante=existing.codigo_estudiante,
                        nombres=existing.nombres,
                        apellidos=existing.apellidos,
                        seccion_id=existing.seccion_id,
                        pin_corto=existing.pin_corto,
                    )
                )

                continue

            estudiante = Estudiante(
                codigo_estudiante=codigo_estudiante,
                nombres=nombres.strip(),
                apellidos=apellidos.strip(),
                fecha_nacimiento=fecha_nacimiento,
                pin_corto=None,
                seccion_id=seccion.id,
                consentimiento_firmado=consentimiento_firmado,
                fecha_consentimiento=(
                    fecha_consentimiento
                    if consentimiento_firmado
                    else None
                ),
                nivel_lectura=1,
                nivel_fonologia=1,
                activo=activo and consentimiento_firmado,
            )

            if consentimiento_firmado:
                estudiante.pin_corto = _generate_pin_for_student(session)

            session.add(estudiante)
            session.commit()
            session.refresh(estudiante)

            created_count += 1

            results.append(
                StudentImportRowResult(
                    row_number=row_number,
                    status="created",
                    message="Estudiante creado.",
                    estudiante_id=estudiante.id,
                    codigo_estudiante=estudiante.codigo_estudiante,
                    nombres=estudiante.nombres,
                    apellidos=estudiante.apellidos,
                    seccion_id=estudiante.seccion_id,
                    pin_corto=estudiante.pin_corto,
                )
            )
        except HTTPException as exc:
            session.rollback()
            error_count += 1
            results.append(
                StudentImportRowResult(
                    row_number=row_number,
                    status="error",
                    message=str(exc.detail),
                )
            )
        except Exception as exc:
            session.rollback()
            error_count += 1
            results.append(
                StudentImportRowResult(
                    row_number=row_number,
                    status="error",
                    message=str(exc),
                )
            )

    return StudentImportResponse(
        filename=file.filename or "archivo",
        total_rows=len(rows),
        created_count=created_count,
        updated_count=updated_count,
        skipped_count=skipped_count,
        error_count=error_count,
        results=results,
    )



@router.patch(
    "/{estudiante_id}",
    response_model=StudentAdminPublic,
)
def update_estudiante(
    estudiante_id: int,
    payload: StudentUpdate,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentAdminPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    if estudiante.seccion_id is not None:
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=estudiante.seccion_id,
            session=session,
        )

    if payload.seccion_id is not None:
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=payload.seccion_id,
            session=session,
        )
        estudiante.seccion_id = payload.seccion_id

    if payload.pin_corto is not None:
        _validate_pin(payload.pin_corto)
        _ensure_pin_is_unique(
            pin_corto=payload.pin_corto,
            session=session,
            exclude_student_id=estudiante_id,
        )
        estudiante.pin_corto = payload.pin_corto

    if payload.codigo_estudiante is not None:
        estudiante.codigo_estudiante = payload.codigo_estudiante.strip()

    if payload.nombres is not None:
        estudiante.nombres = payload.nombres.strip()

    if payload.apellidos is not None:
        estudiante.apellidos = payload.apellidos.strip()

    if payload.fecha_nacimiento is not None:
        estudiante.fecha_nacimiento = payload.fecha_nacimiento

    if payload.consentimiento_firmado is not None:
        estudiante.consentimiento_firmado = payload.consentimiento_firmado

        if not payload.consentimiento_firmado:
            estudiante.activo = False

    if payload.fecha_consentimiento is not None:
        estudiante.fecha_consentimiento = payload.fecha_consentimiento

    if estudiante.consentimiento_firmado and estudiante.fecha_consentimiento is None:
        raise HTTPException(
            status_code=400,
            detail="Debe registrar la fecha del consentimiento firmado.",
        )

    if payload.nivel_lectura is not None:
        estudiante.nivel_lectura = payload.nivel_lectura

    if payload.nivel_fonologia is not None:
        estudiante.nivel_fonologia = payload.nivel_fonologia

    if payload.activo is not None:
        if payload.activo and not estudiante.consentimiento_firmado:
            raise HTTPException(
                status_code=400,
                detail="No se puede activar un estudiante sin consentimiento firmado.",
            )

        estudiante.activo = payload.activo

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentAdminPublic.model_validate(estudiante)


@router.post(
    "/{estudiante_id}/regenerar-pin",
    response_model=StudentAdminPublic,
)
def regenerate_student_pin(
    estudiante_id: int,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentAdminPublic:
    if current_user.rol.upper() not in {"DIRECTORA", "MAESTRO"}:
        _raise_forbidden()

    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    if estudiante.seccion_id is not None:
        _ensure_user_can_manage_section(
            usuario=current_user,
            seccion_id=estudiante.seccion_id,
            session=session,
        )

    estudiante.pin_corto = _generate_pin_for_student(session)

    session.add(estudiante)
    session.commit()
    session.refresh(estudiante)

    return StudentAdminPublic.model_validate(estudiante)




def _get_active_jornada_for_section(
    seccion_id: int,
    session: Session,
) -> JornadaEvaluacion | None:
    now = datetime.utcnow()

    jornada = session.exec(
        select(JornadaEvaluacion)
        .where(
            JornadaEvaluacion.seccion_id == seccion_id,
            JornadaEvaluacion.estado == "ACTIVA",
        )
        .order_by(JornadaEvaluacion.fecha_inicio.desc())
    ).first()

    if jornada is None:
        return None

    if jornada.fecha_expiracion is not None and jornada.fecha_expiracion <= now:
        jornada.estado = "EXPIRADA"
        jornada.fecha_cierre = now
        jornada.updated_at = now

        session.add(jornada)
        session.commit()

        return None

    return jornada


@router.get(
    "/modo-aula/{seccion_id}/pin/{pin_corto}",
    response_model=StudentPublic,
)
def get_estudiante_by_pin_for_modo_aula(
    seccion_id: int,
    pin_corto: str,
    session: Session = Depends(get_session),
) -> StudentPublic:
    _validate_pin(pin_corto)
    _ensure_section_exists(seccion_id, session)

    jornada = _get_active_jornada_for_section(
        seccion_id=seccion_id,
        session=session,
    )

    if jornada is None:
        raise HTTPException(
            status_code=403,
            detail="No hay jornada activa para esta seccion.",
        )

    estudiante = session.exec(
        select(Estudiante).where(
            Estudiante.seccion_id == seccion_id,
            Estudiante.pin_corto == pin_corto,
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
    ).first()

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="No se encontro estudiante activo con consentimiento firmado para esta seccion y PIN.",
        )

    return StudentPublic.model_validate(estudiante)


@router.get("/pin/{pin_corto}", response_model=StudentPublic)
def get_estudiante_by_pin(
    pin_corto: str,
    session: Session = Depends(get_session),
) -> StudentPublic:
    _validate_pin(pin_corto)

    estudiante = session.exec(
        select(Estudiante).where(
            Estudiante.pin_corto == pin_corto,
            Estudiante.activo == True,  # noqa: E712
            Estudiante.consentimiento_firmado == True,  # noqa: E712
        )
    ).first()

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="No se encontró estudiante activo con consentimiento firmado para ese PIN.",
        )

    return StudentPublic.model_validate(estudiante)
