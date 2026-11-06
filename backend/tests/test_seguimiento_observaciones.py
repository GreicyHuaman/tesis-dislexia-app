import json
import unittest
from datetime import datetime, timedelta
from typing import get_args

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.api.seguimiento import router
from app.core.security import get_current_user
from app.db.session import get_session
from app.models.evaluation import Evaluacion
from app.models.section import DocenteSeccion, Seccion
from app.models.seguimiento import SeguimientoEstudiante
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.seguimiento_schema import ObservationCategory


URL = "/api/v1/seguimiento"
CATEGORIES = [
    "Refuerzo pedagógico", "Reevaluación", "Coordinación con familia",
    "Seguimiento general", "Otro",
]


class ObservationApiTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        SQLModel.metadata.create_all(self.engine)
        self.app = FastAPI()
        self.app.include_router(router)
        self.user = Usuario(
            id=1, nombres="Docente", apellidos="Prueba", email="docente@edu.com",
            rol="MAESTRO", password_hash="unused-in-test",
        )

        def local_session():
            with Session(self.engine) as session:
                yield session

        self.app.dependency_overrides[get_session] = local_session
        self.app.dependency_overrides[get_current_user] = lambda: self.user
        self.client = TestClient(self.app)
        self.addCleanup(self.engine.dispose)
        self.addCleanup(self.client.close)
        with Session(self.engine) as session:
            session.add(self.user)
            session.add_all([
                Seccion(id=1, grado=3, nombre="A"),
                Seccion(id=2, grado=3, nombre="B"),
                DocenteSeccion(usuario_id=1, seccion_id=1),
                Estudiante(
                    id=1, nombres="Estudiante", apellidos="Prueba",
                    seccion_id=1, activo=True, consentimiento_firmado=True,
                ),
                Estudiante(
                    id=2, nombres="Estudiante", apellidos="Ajeno",
                    seccion_id=2, activo=True, consentimiento_firmado=True,
                ),
                Evaluacion(
                    id=1, estudiante_id=1, fecha_evaluacion=datetime.utcnow(),
                    tipo_prueba="LECTURA", semaforo="VERDE", porcentaje_riesgo=20,
                ),
            ])
            session.commit()
            session.refresh(self.user)

    def payload(self, **overrides):
        data = {
            "estudiante_id": 1,
            "evaluacion_id": 1,
            "observacion_docente": "Reforzar lectura de sílabas.",
            "categorias": ["Refuerzo pedagógico"],
            "estado": "REFORZAMIENTO",
        }
        data.update(overrides)
        return data

    def post(self, **overrides):
        response = self.client.post(f"{URL}/observaciones", json=self.payload(**overrides))
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def count(self):
        with Session(self.engine) as session:
            return len(session.exec(select(SeguimientoEstudiante)).all())

    def test_catalog_matches_hu0035_exactly(self):
        self.assertEqual(list(get_args(ObservationCategory)), CATEGORIES)

    def test_cp035_saves_and_persists_date_category_and_authenticated_author(self):
        before = datetime.utcnow()
        created = self.post(responsable_id=999, responsable_nombre="No autorizado")
        self.assertEqual(created["estado"], "REFORZAMIENTO")
        self.assertEqual(created["responsable_id"], 1)
        self.assertEqual(created["responsable_nombre"], "Docente Prueba")
        self.assertEqual(created["responsable_cargo"], "MAESTRO")
        self.assertGreaterEqual(datetime.fromisoformat(created["fecha_seguimiento"]), before)
        self.assertEqual(created["evaluacion_id"], 1)
        with Session(self.engine) as session:
            stored = session.get(SeguimientoEstudiante, created["id"])
            self.assertEqual(stored.observacion_docente, "Reforzar lectura de sílabas.")
            self.assertEqual(json.loads(stored.categorias_json), ["Refuerzo pedagógico"])
            self.assertEqual(stored.responsable_id, 1)
        for _ in range(2):
            history = self.client.get(f"{URL}/estudiante/1")
            self.assertEqual(history.status_code, 200, history.text)
            entry = history.json()["observaciones"][0]
            self.assertEqual(entry, created)
            self.assertEqual(history.json()["actual"]["categorias"], ["Refuerzo pedagógico"])
        self.assertEqual(self.count(), 1)

    def test_every_catalog_category_can_be_saved(self):
        for category in CATEGORIES:
            with self.subTest(category=category):
                result = self.post(categorias=[category])
                self.assertEqual(json.loads(result["categorias_json"]), [category])
        self.assertEqual(self.count(), 5)

    def test_multiple_valid_categories_remain_supported(self):
        result = self.post(categorias=CATEGORIES)
        self.assertEqual(json.loads(result["categorias_json"]), CATEGORIES)

    def test_create_rejects_invalid_categories_without_any_write(self):
        for value in [
            [], None, [""], ["  "], ["Lectura lenta"], ["Reevaluacion"],
            ["No permitida"], ["Refuerzo pedagógico", "No permitida"],
            "Refuerzo pedagógico", [1],
        ]:
            with self.subTest(value=value):
                response = self.client.post(
                    f"{URL}/observaciones", json=self.payload(categorias=value),
                )
                self.assertEqual(response.status_code, 422, response.text)
                self.assertEqual(self.count(), 0)
        data = self.payload()
        del data["categorias"]
        response = self.client.post(f"{URL}/observaciones", json=data)
        self.assertEqual(response.status_code, 422)
        self.assertEqual(self.count(), 0)

    def test_patch_rejects_invalid_replacement_and_keeps_stored_observation(self):
        created = self.post()
        for categories in [[], None, ["Lectura lenta"], ["Otro", "No permitida"]]:
            with self.subTest(categories=categories):
                response = self.client.patch(f"{URL}/{created['id']}", json={
                    "categorias": categories, "observacion_docente": "No debe guardarse",
                })
                self.assertEqual(response.status_code, 422, response.text)
                with Session(self.engine) as session:
                    stored = session.get(SeguimientoEstudiante, created["id"])
                    self.assertEqual(json.loads(stored.categorias_json), ["Refuerzo pedagógico"])
                    self.assertEqual(stored.observacion_docente, "Reforzar lectura de sílabas.")
        self.assertEqual(self.count(), 1)

    def test_patch_accepts_each_valid_category_and_omission_keeps_categories(self):
        created = self.post()
        for category in CATEGORIES:
            response = self.client.patch(f"{URL}/{created['id']}", json={"categorias": [category]})
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(json.loads(response.json()["categorias_json"]), [category])
        response = self.client.patch(
            f"{URL}/{created['id']}", json={"observacion_docente": "Texto actualizado"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(json.loads(response.json()["categorias_json"]), ["Otro"])

    def test_legacy_history_is_readable_and_not_automatically_reclassified(self):
        with Session(self.engine) as session:
            old = SeguimientoEstudiante(
                estudiante_id=1, evaluacion_id=1,
                fecha_seguimiento=datetime.utcnow() - timedelta(days=1),
                observacion_docente="Nota previa",
                categorias_json=json.dumps(["Lectura lenta"], ensure_ascii=False),
            )
            session.add(old)
            session.commit()
            old_id = old.id
        new = self.post()
        history = self.client.get(f"{URL}/estudiante/1").json()
        self.assertEqual(len(history["observaciones"]), 2)
        self.assertEqual(history["observaciones"][0]["id"], new["id"])
        self.assertEqual(json.loads(history["observaciones"][1]["categorias_json"]), ["Lectura lenta"])
        response = self.client.patch(f"{URL}/{old_id}", json={"estado": "REFORZAMIENTO"})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(json.loads(response.json()["categorias_json"]), ["Lectura lenta"])

    def test_observation_without_evaluation_remains_allowed_as_separate_case(self):
        with Session(self.engine) as session:
            session.delete(session.get(Evaluacion, 1))
            session.commit()
        created = self.post(evaluacion_id=None)
        self.assertIsNone(created["evaluacion_id"])

    def test_mandatory_text_rules_remain_for_red_overdue_and_restricted_states(self):
        for state in ["DERIVACION_SUGERIDA", "CERRADO", "CAMBIO_MANUAL"]:
            with self.subTest(state=state):
                response = self.client.post(
                    f"{URL}/observaciones", json=self.payload(estado=state, observacion_docente="  "),
                )
                self.assertEqual(response.status_code, 400, response.text)
        for red, overdue in [(True, False), (False, True)]:
            with self.subTest(red=red, overdue=overdue):
                with Session(self.engine) as session:
                    evaluation = session.get(Evaluacion, 1)
                    evaluation.semaforo = "ROJO" if red else "VERDE"
                    evaluation.fecha_evaluacion = datetime.utcnow() - timedelta(days=8 if overdue else 0)
                    session.add(evaluation)
                    session.commit()
                response = self.client.post(
                    f"{URL}/observaciones", json=self.payload(observacion_docente=""),
                )
                self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.count(), 0)

    def test_catalog_does_not_change_optional_text_rule_for_green(self):
        created = self.post(observacion_docente="", estado="ABIERTO")
        self.assertIsNone(created["observacion_docente"])

    def test_teacher_cannot_write_or_read_another_section(self):
        response = self.client.post(f"{URL}/observaciones", json=self.payload(estudiante_id=2))
        self.assertEqual(response.status_code, 403)
        self.assertEqual(self.client.get(f"{URL}/estudiante/2").status_code, 403)
        self.assertEqual(self.count(), 0)

    def test_authentication_required_for_saving(self):
        del self.app.dependency_overrides[get_current_user]
        self.assertEqual(
            self.client.post(f"{URL}/observaciones", json=self.payload()).status_code, 401,
        )
        self.assertEqual(self.count(), 0)


if __name__ == "__main__":
    unittest.main()
