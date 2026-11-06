from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.admin_demo import router as admin_demo_router
from app.api.admin_usuarios import router as admin_usuarios_router
from app.api.auth import router as auth_router
from app.api.docente_seccion import router as docente_seccion_router
from app.api.estudiantes import router as estudiantes_router
from app.api.jornadas_evaluacion import router as jornadas_evaluacion_router
from app.api.evaluaciones import router as evaluaciones_router
from app.api.ml_dataset import router as ml_dataset_router
from app.api.reportes import router as reportes_router
from app.api.seguimiento import router as seguimiento_router
from app.api.secciones import router as secciones_router
from app.db.session import create_db_and_tables
from app.services.jwt_service import validate_jwt_configuration

from app.models.evaluation import DetalleEvaluacion, Evaluacion  # noqa: F401
from app.models.jornada import JornadaEvaluacion  # noqa: F401
from app.models.prediction import PrediccionModelo  # noqa: F401
from app.models.section import DocenteSeccion, Seccion  # noqa: F401
from app.models.seguimiento import SeguimientoEstudiante  # noqa: F401
from app.models.student import Estudiante  # noqa: F401
from app.models.user import Usuario  # noqa: F401


app = FastAPI(
    title="API Cribado de Riesgo de Dislexia",
    version="0.1.0",
    description="Backend para app offline-first de tamizaje educativo de riesgo de dislexia.",
)

@app.middleware("http")
async def add_utf8_charset_for_json(request, call_next):
    response = await call_next(request)
    content_type = response.headers.get("content-type", "")
    if content_type.startswith("application/json") and "charset" not in content_type.lower():
        response.headers["content-type"] = "application/json; charset=utf-8"
    return response



app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://localhost:8080",
    ],
    allow_origin_regex=r"http://localhost:\d+|http://127\.0\.0\.1:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    validate_jwt_configuration()
    create_db_and_tables()


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "dyslexia-screening-api",
        "version": "0.1.0",
    }


app.include_router(auth_router)
app.include_router(admin_demo_router)
app.include_router(admin_usuarios_router)
app.include_router(docente_seccion_router)
app.include_router(secciones_router)
app.include_router(estudiantes_router)
app.include_router(jornadas_evaluacion_router)
app.include_router(evaluaciones_router)
app.include_router(reportes_router)
app.include_router(seguimiento_router)
app.include_router(ml_dataset_router)
