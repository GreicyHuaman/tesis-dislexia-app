import csv
import io
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy import func
from sqlmodel import Session, select

from app.core.security import get_current_user, require_roles
from app.db.session import get_session
from app.models.evaluation import Evaluacion
from app.models.prediction import PrediccionModelo
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.report_schema import (
    EvaluationReportItem,
    InstitutionalSummaryResponse,
    ReportSummaryResponse,
    SemaforoSummaryItem,
    StudentRiskProfileResponse,
    StudentTestProfile,
)

router = APIRouter(
    prefix="/api/v1/reportes",
    tags=["reportes"],
)


def _build_student_name(estudiante: Estudiante | None) -> str | None:
    if estudiante is None:
        return None

    return f"{estudiante.nombres} {estudiante.apellidos}".strip()


def _to_report_item(
    evaluacion: Evaluacion,
    estudiante: Estudiante | None,
    prediccion: PrediccionModelo | None,
) -> EvaluationReportItem:
    return EvaluationReportItem(
        id=evaluacion.id or 0,
        estudiante_id=evaluacion.estudiante_id,
        estudiante_nombre=_build_student_name(estudiante),
        seccion_id=estudiante.seccion_id if estudiante else None,
        fecha_evaluacion=evaluacion.fecha_evaluacion,
        tipo_prueba=evaluacion.tipo_prueba,
        total_items=evaluacion.total_items,
        aciertos_primer_intento=evaluacion.aciertos_primer_intento,
        taps_erroneos_totales=evaluacion.taps_erroneos_totales,
        tiempo_promedio_ms=evaluacion.tiempo_promedio_ms,
        porcentaje_riesgo=evaluacion.porcentaje_riesgo,
        semaforo=evaluacion.semaforo,
        fuente_prediccion=prediccion.fuente_prediccion if prediccion else None,
        modelo_nombre=prediccion.modelo_nombre if prediccion else None,
        modelo_version=prediccion.modelo_version if prediccion else None,
        probabilidad_verde=prediccion.probabilidad_verde if prediccion else None,
        probabilidad_amarillo=prediccion.probabilidad_amarillo if prediccion else None,
        probabilidad_rojo=prediccion.probabilidad_rojo if prediccion else None,
    )


def _get_allowed_section_ids_for_user(
    usuario: Usuario,
    session: Session,
) -> list[int] | None:
    rol = usuario.rol.upper()

    if rol == "MAESTRO":
        if usuario.id is None:
            return []

        links = session.exec(
            select(DocenteSeccion).where(
                DocenteSeccion.usuario_id == usuario.id,
            )
        ).all()

        return [
            link.seccion_id
            for link in links
        ]

    if rol in {"PSICOLOGA", "DIRECTORA"}:
        if usuario.grado_scope is None:
            return None

        secciones = session.exec(
            select(Seccion).where(
                Seccion.grado == usuario.grado_scope,
                Seccion.activo == True,  # noqa: E712
            )
        ).all()

        return [
            seccion.id
            for seccion in secciones
            if seccion.id is not None
        ]

    return []


def _get_allowed_section_ids_legacy(
    usuario_id: int | None,
    session: Session,
) -> list[int] | None:
    """
    Uso temporal para export CSV abierto desde navegador.
    Los endpoints JSON ya usan JWT.
    """
    if usuario_id is None:
        return None

    usuario = session.get(Usuario, usuario_id)

    if usuario is None or not usuario.activo:
        return []

    return _get_allowed_section_ids_for_user(usuario, session)


def _normalize_optional_text(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip().upper()

    if normalized in {"", "TODOS", "TODAS", "ALL"}:
        return None

    return normalized


def _base_evaluaciones_statement():
    return (
        select(Evaluacion, Estudiante, PrediccionModelo)
        .join(
            Estudiante,
            Evaluacion.estudiante_id == Estudiante.id,
            isouter=True,
        )
        .join(
            PrediccionModelo,
            PrediccionModelo.evaluacion_id == Evaluacion.id,
            isouter=True,
        )
    )


def _apply_section_filter(statement, allowed_section_ids: list[int] | None):
    if allowed_section_ids is None:
        return statement

    return statement.where(
        Estudiante.seccion_id.in_(allowed_section_ids),
    )


def _apply_report_filters(
    statement,
    tipo_prueba: str | None,
    semaforo: str | None,
    estudiante_id: int | None,
):
    normalized_tipo_prueba = _normalize_optional_text(tipo_prueba)
    normalized_semaforo = _normalize_optional_text(semaforo)

    if normalized_tipo_prueba is not None:
        statement = statement.where(
            Evaluacion.tipo_prueba == normalized_tipo_prueba,
        )

    if normalized_semaforo is not None:
        statement = statement.where(
            Evaluacion.semaforo == normalized_semaforo,
        )

    if estudiante_id is not None:
        statement = statement.where(
            Evaluacion.estudiante_id == estudiante_id,
        )

    return statement


def _average_optional(values: list[float | int | None]) -> Optional[float]:
    clean_values = [
        float(value)
        for value in values
        if value is not None
    ]

    if not clean_values:
        return None

    return round(sum(clean_values) / len(clean_values), 2)


def _count_semaforos(evaluaciones: list[Evaluacion]) -> dict[str, int]:
    counts = {
        "VERDE": 0,
        "AMARILLO": 0,
        "ROJO": 0,
        "SIN_RESULTADO": 0,
    }

    for evaluacion in evaluaciones:
        semaforo = evaluacion.semaforo or "SIN_RESULTADO"

        if semaforo not in counts:
            counts[semaforo] = 0

        counts[semaforo] += 1

    return counts


def _latest_evaluation(evaluaciones: list[Evaluacion]) -> Evaluacion | None:
    if not evaluaciones:
        return None

    return sorted(
        evaluaciones,
        key=lambda item: item.fecha_evaluacion,
        reverse=True,
    )[0]


@router.get("/evaluaciones", response_model=list[EvaluationReportItem])
def list_evaluaciones_report(
    tipo_prueba: str | None = Query(default=None),
    semaforo: str | None = Query(default=None),
    estudiante_id: int | None = Query(default=None),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[EvaluationReportItem]:
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=current_user,
        session=session,
    )

    if allowed_section_ids == []:
        return []

    statement = _base_evaluaciones_statement()
    statement = _apply_section_filter(statement, allowed_section_ids)
    statement = _apply_report_filters(
        statement=statement,
        tipo_prueba=tipo_prueba,
        semaforo=semaforo,
        estudiante_id=estudiante_id,
    )
    statement = statement.order_by(Evaluacion.fecha_evaluacion.desc())

    rows = session.exec(statement).all()

    return [
        _to_report_item(evaluacion, estudiante, prediccion)
        for evaluacion, estudiante, prediccion in rows
    ]


@router.get(
    "/estudiantes/{estudiante_id}/evaluaciones",
    response_model=list[EvaluationReportItem],
)
def list_evaluaciones_by_estudiante(
    estudiante_id: int,
    tipo_prueba: str | None = Query(default=None),
    semaforo: str | None = Query(default=None),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> list[EvaluationReportItem]:
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=current_user,
        session=session,
    )

    if allowed_section_ids == []:
        return []

    statement = _base_evaluaciones_statement()
    statement = statement.where(Evaluacion.estudiante_id == estudiante_id)
    statement = _apply_section_filter(statement, allowed_section_ids)
    statement = _apply_report_filters(
        statement=statement,
        tipo_prueba=tipo_prueba,
        semaforo=semaforo,
        estudiante_id=None,
    )
    statement = statement.order_by(Evaluacion.fecha_evaluacion.desc())

    rows = session.exec(statement).all()

    return [
        _to_report_item(evaluacion, estudiante, prediccion)
        for evaluacion, estudiante, prediccion in rows
    ]


@router.get(
    "/resumen-institucional",
    response_model=InstitutionalSummaryResponse,
    dependencies=[Depends(require_roles("DIRECTORA"))],
)
def get_resumen_institucional(
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> InstitutionalSummaryResponse:
    sections = select(func.count(Seccion.id))
    students = select(func.count(Estudiante.id))
    evaluations = select(func.count(Evaluacion.id))
    students_with_evaluations = select(func.count(Estudiante.id)).where(
        Estudiante.id.in_(select(Evaluacion.estudiante_id)),
    )

    if current_user.grado_scope is not None:
        section_ids = select(Seccion.id).where(
            Seccion.grado == current_user.grado_scope,
        )
        student_ids = select(Estudiante.id).where(
            Estudiante.seccion_id.in_(section_ids),
        )
        sections = sections.where(Seccion.grado == current_user.grado_scope)
        students = students.where(Estudiante.seccion_id.in_(section_ids))
        evaluations = evaluations.where(Evaluacion.estudiante_id.in_(student_ids))
        students_with_evaluations = students_with_evaluations.where(
            Estudiante.seccion_id.in_(section_ids),
        )

    # Una sentencia conserva un mismo instante para todos los indicadores.
    counts = select(
        sections.scalar_subquery(),
        sections.where(Seccion.activo == True).scalar_subquery(),  # noqa: E712
        students.scalar_subquery(),
        students.where(Estudiante.activo == True).scalar_subquery(),  # noqa: E712
        evaluations.scalar_subquery(),
        students_with_evaluations.scalar_subquery(),
    )
    (
        total_sections,
        active_sections,
        total_students,
        active_students,
        total_evaluations,
        evaluated_students,
    ) = session.exec(counts).one()

    return InstitutionalSummaryResponse(
        total_secciones=total_sections,
        secciones_activas=active_sections,
        secciones_inactivas=total_sections - active_sections,
        total_estudiantes=total_students,
        estudiantes_activos=active_students,
        estudiantes_inactivos=total_students - active_students,
        total_evaluaciones=total_evaluations,
        estudiantes_con_evaluaciones=evaluated_students,
        estudiantes_sin_evaluaciones=total_students - evaluated_students,
    )


@router.get("/resumen-semaforo", response_model=ReportSummaryResponse)
def get_resumen_semaforo(
    tipo_prueba: str | None = Query(default=None),
    semaforo: str | None = Query(default=None),
    estudiante_id: int | None = Query(default=None),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> ReportSummaryResponse:
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=current_user,
        session=session,
    )

    if allowed_section_ids == []:
        return ReportSummaryResponse(
            total_evaluaciones=0,
            porcentaje_promedio_riesgo=None,
            semaforos=[
                SemaforoSummaryItem(semaforo="VERDE", total=0),
                SemaforoSummaryItem(semaforo="AMARILLO", total=0),
                SemaforoSummaryItem(semaforo="ROJO", total=0),
                SemaforoSummaryItem(semaforo="SIN_RESULTADO", total=0),
            ],
        )

    statement = _base_evaluaciones_statement()
    statement = _apply_section_filter(statement, allowed_section_ids)
    statement = _apply_report_filters(
        statement=statement,
        tipo_prueba=tipo_prueba,
        semaforo=semaforo,
        estudiante_id=estudiante_id,
    )

    rows = session.exec(statement).all()

    evaluaciones = [
        evaluacion
        for evaluacion, _estudiante, _prediccion in rows
    ]

    counts = _count_semaforos(evaluaciones)

    risk_values = [
        evaluacion.porcentaje_riesgo
        for evaluacion in evaluaciones
        if evaluacion.porcentaje_riesgo is not None
    ]

    porcentaje_promedio = None

    if risk_values:
        porcentaje_promedio = round(
            sum(risk_values) / len(risk_values),
            2,
        )

    return ReportSummaryResponse(
        total_evaluaciones=len(evaluaciones),
        porcentaje_promedio_riesgo=porcentaje_promedio,
        semaforos=[
            SemaforoSummaryItem(
                semaforo=current_semaforo,
                total=total,
            )
            for current_semaforo, total in counts.items()
        ],
    )


@router.get(
    "/estudiantes/{estudiante_id}/perfil-riesgo",
    response_model=StudentRiskProfileResponse,
)
def get_perfil_riesgo_estudiante(
    estudiante_id: int,
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> StudentRiskProfileResponse:
    estudiante = session.get(Estudiante, estudiante_id)

    if estudiante is None:
        raise HTTPException(
            status_code=404,
            detail="Estudiante no encontrado.",
        )

    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=current_user,
        session=session,
    )

    if allowed_section_ids == []:
        raise HTTPException(
            status_code=403,
            detail="Usuario sin acceso a evaluaciones.",
        )

    if (
        allowed_section_ids is not None
        and estudiante.seccion_id not in allowed_section_ids
    ):
        raise HTTPException(
            status_code=403,
            detail="El usuario no tiene acceso a este estudiante.",
        )

    statement = (
        _base_evaluaciones_statement()
        .where(Evaluacion.estudiante_id == estudiante_id)
        .order_by(Evaluacion.fecha_evaluacion.desc())
    )

    rows = session.exec(statement).all()

    evaluaciones = [
        evaluacion
        for evaluacion, _estudiante, _prediccion in rows
    ]

    latest_general = _latest_evaluation(evaluaciones)

    by_test_type: dict[str, list[Evaluacion]] = {}

    for evaluacion in evaluaciones:
        tipo_prueba = (evaluacion.tipo_prueba or "SIN_TIPO").upper()

        if tipo_prueba not in by_test_type:
            by_test_type[tipo_prueba] = []

        by_test_type[tipo_prueba].append(evaluacion)

    perfiles_prueba: list[StudentTestProfile] = []

    for tipo_prueba, evals in sorted(by_test_type.items()):
        latest = _latest_evaluation(evals)
        counts = _count_semaforos(evals)

        perfiles_prueba.append(
            StudentTestProfile(
                tipo_prueba=tipo_prueba,
                total_evaluaciones=len(evals),
                porcentaje_promedio_riesgo=_average_optional(
                    [
                        evaluacion.porcentaje_riesgo
                        for evaluacion in evals
                    ]
                ),
                ultimo_porcentaje_riesgo=(
                    latest.porcentaje_riesgo if latest else None
                ),
                ultimo_semaforo=latest.semaforo if latest else None,
                ultima_fecha=latest.fecha_evaluacion if latest else None,
                promedio_tiempo_ms=_average_optional(
                    [
                        evaluacion.tiempo_promedio_ms
                        for evaluacion in evals
                    ]
                ),
                promedio_errores=_average_optional(
                    [
                        evaluacion.taps_erroneos_totales
                        for evaluacion in evals
                    ]
                ),
                total_verde=counts.get("VERDE", 0),
                total_amarillo=counts.get("AMARILLO", 0),
                total_rojo=counts.get("ROJO", 0),
                total_sin_resultado=counts.get("SIN_RESULTADO", 0),
            )
        )

    return StudentRiskProfileResponse(
        estudiante_id=estudiante.id or estudiante_id,
        estudiante_nombre=_build_student_name(estudiante),
        seccion_id=estudiante.seccion_id,
        total_evaluaciones=len(evaluaciones),
        porcentaje_promedio_general=_average_optional(
            [
                evaluacion.porcentaje_riesgo
                for evaluacion in evaluaciones
            ]
        ),
        ultimo_porcentaje_riesgo_general=(
            latest_general.porcentaje_riesgo if latest_general else None
        ),
        ultimo_semaforo_general=(
            latest_general.semaforo if latest_general else None
        ),
        ultima_fecha_general=(
            latest_general.fecha_evaluacion if latest_general else None
        ),
        pruebas=perfiles_prueba,
    )


@router.get("/evaluaciones.csv")
def export_evaluaciones_csv(
    tipo_prueba: str | None = Query(default=None),
    semaforo: str | None = Query(default=None),
    estudiante_id: int | None = Query(default=None),
    current_user: Usuario = Depends(get_current_user),
    session: Session = Depends(get_session),
) -> Response:
    """
    Endpoint protegido con JWT para exportar reportes CSV.
    """
    allowed_section_ids = _get_allowed_section_ids_for_user(
        usuario=current_user,
        session=session,
    )

    rows = []

    if allowed_section_ids != []:
        statement = _base_evaluaciones_statement()
        statement = _apply_section_filter(statement, allowed_section_ids)
        statement = _apply_report_filters(
            statement=statement,
            tipo_prueba=tipo_prueba,
            semaforo=semaforo,
            estudiante_id=estudiante_id,
        )
        statement = statement.order_by(Evaluacion.fecha_evaluacion.desc())

        rows = session.exec(statement).all()

    output = io.StringIO()
    fieldnames = list(EvaluationReportItem.model_fields.keys())

    writer = csv.DictWriter(
        output,
        fieldnames=fieldnames,
        extrasaction="ignore",
    )
    writer.writeheader()

    for evaluacion, estudiante, prediccion in rows:
        item = _to_report_item(
            evaluacion=evaluacion,
            estudiante=estudiante,
            prediccion=prediccion,
        ).model_dump()

        fecha = item.get("fecha_evaluacion")

        if hasattr(fecha, "isoformat"):
            item["fecha_evaluacion"] = fecha.isoformat()

        writer.writerow(item)

    csv_content = "\ufeff" + output.getvalue()

    return Response(
        content=csv_content,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": "attachment; filename=reporte_evaluaciones.csv",
        },
    )
