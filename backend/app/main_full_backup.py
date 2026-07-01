from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.evaluaciones import router as evaluaciones_router
from app.db.session import create_db_and_tables

# Importamos modelos para que SQLModel registre las tablas.
from app.models.evaluation import DetalleEvaluacion, Evaluacion  # noqa: F401
from app.models.student import Estudiante  # noqa: F401


app = FastAPI(
    title="API Cribado de Riesgo de Dislexia",
    version="0.1.0",
    description="Backend para app offline-first de tamizaje temprano de riesgo de dislexia.",
)


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
    create_db_and_tables()


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "dyslexia-screening-api",
        "version": "0.1.0",
    }


app.include_router(evaluaciones_router)

