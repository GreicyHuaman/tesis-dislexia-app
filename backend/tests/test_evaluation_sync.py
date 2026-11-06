import copy
import os
import secrets
import sqlite3
import unittest
from datetime import date, datetime, timedelta, timezone
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import inspect
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.api.evaluaciones import router
from app.db.session import get_session
from app.models.evaluation import DetalleEvaluacion, Evaluacion
from app.models.prediction import PrediccionModelo
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario
from app.services.jwt_service import create_access_token


URL = "/api/v1/evaluaciones/sync"
MODEL = {
    "porcentaje_riesgo": 10.0,
    "semaforo": "VERDE",
    "fuente_prediccion": "QA_LOCAL",
    "modelo_nombre": "ficticio",
    "modelo_version": "test",
}


class EvaluationSyncTests(unittest.TestCase):
    def setUp(self):
        environment = patch.dict(os.environ, {"JWT_SECRET_KEY": secrets.token_urlsafe(48)})
        environment.start()
        self.addCleanup(environment.stop)
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool,
        )
        SQLModel.metadata.create_all(self.engine)
        self.addCleanup(self.engine.dispose)
        with Session(self.engine) as session:
            session.add_all([
                Seccion(id=1, grado=3, nombre="A", turno="MAÑANA"),
                Seccion(id=2, grado=3, nombre="B", turno="TARDE"),
                Usuario(id=1, nombres="Dirección", apellidos="Prueba", email="dir@edu.com",
                        rol="DIRECTORA", password_hash="unused-in-test", activo=True),
                Usuario(id=2, nombres="Docente", apellidos="Prueba", email="doc@edu.com",
                        rol="MAESTRO", password_hash="unused-in-test", activo=True),
                Usuario(id=3, nombres="Psicología", apellidos="Prueba", email="psi@edu.com",
                        rol="PSICOLOGA", password_hash="unused-in-test", activo=True),
                DocenteSeccion(usuario_id=2, seccion_id=1),
                Estudiante(id=1, nombres="Ficticio", apellidos="Uno", seccion_id=1,
                           activo=True, consentimiento_firmado=True, fecha_consentimiento=date(2026, 1, 1)),
                Estudiante(id=2, nombres="Ficticio", apellidos="Dos", seccion_id=2,
                           activo=True, consentimiento_firmado=True, fecha_consentimiento=date(2026, 1, 1)),
            ])
            session.commit()

        def local_session():
            with Session(self.engine) as session:
                yield session

        self.app = FastAPI()
        self.app.include_router(router)
        self.app.dependency_overrides[get_session] = local_session
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)
        predictor = patch("app.api.evaluaciones.predict_risk_with_ml", return_value=MODEL)
        self.predictor = predictor.start()
        self.addCleanup(predictor.stop)

    def headers(self, user_id=1):
        token = create_access_token(user_id=user_id, email="ficticio@edu.com", rol="DIRECTORA")
        return {"Authorization": f"Bearer {token}"}

    def payload(self, identity="session-a", *, student_id=1, tipo="LECTURA"):
        start = datetime(2026, 11, 5, 12, tzinfo=timezone.utc)
        session = {
            "local_session_id": identity, "estudiante_id": student_id, "tipo_prueba": tipo,
            "fecha_inicio": start.isoformat(), "fecha_fin": (start + timedelta(minutes=1)).isoformat(),
            "total_items": 10, "aciertos_primer_intento": 10, "taps_erroneos_totales": 0,
            "tiempo_promedio_ms": 1000, "sync_status": "COMPLETED_PENDING_SYNC",
            "nivel_dificultad_aplicado": 1, "total_baja": 10,
        }
        details = [{
            "local_session_id": identity, "local_detail_id": f"{identity}:{index}",
            "stimulus_id": f"stimulus-{index}", "texto": "ficticio", "tipo_prueba": tipo,
            "tiempo_respuesta_ms": 1000,
            "duracion_drag_drop_ms": 1000 if tipo == "FONOLOGIA" else None,
            "taps_erroneos": 0, "tipo_error": None, "complejidad_estimulo": "BAJA", "acierto": True,
        } for index in range(10)]
        return {"sessions": [session], "details": details}

    def send(self, payload=None, *, user_id=1):
        return self.client.post(URL, json=payload or self.payload(), headers=self.headers(user_id))

    def counts(self):
        with Session(self.engine) as session:
            return tuple(len(session.exec(select(model)).all()) for model in (
                Evaluacion, DetalleEvaluacion, PrediccionModelo,
            ))

    def change_student(self, **changes):
        with Session(self.engine) as session:
            student = session.get(Estudiante, 1)
            for name, value in changes.items():
                setattr(student, name, value)
            session.add(student)
            session.commit()

    def test_requires_real_institutional_authentication(self):
        for headers in ({}, {"Authorization": "Bearer invalid"}):
            with self.subTest(headers_present=bool(headers)):
                response = self.client.post(URL, json=self.payload(), headers=headers)
                self.assertEqual(response.status_code, 401)
        self.assertEqual(self.counts(), (0, 0, 0))

    def test_teacher_scope_and_director_access(self):
        self.assertEqual(self.send(user_id=2).status_code, 200)
        self.assertEqual(self.send(self.payload("foreign", student_id=2), user_id=2).status_code, 403)
        self.assertEqual(self.send(self.payload("director", student_id=2)).status_code, 200)
        self.assertEqual(self.send(self.payload("psychology"), user_id=3).status_code, 403)
        self.assertEqual(self.counts(), (2, 20, 2))

    def test_inactive_institutional_user_is_not_authorized(self):
        with Session(self.engine) as session:
            user = session.get(Usuario, 1)
            user.activo = False
            session.add(user)
            session.commit()
        self.assertEqual(self.send().status_code, 401)
        self.assertEqual(self.counts(), (0, 0, 0))

    def test_blocked_student_is_preserved_until_regularized(self):
        for changes in (
            {"activo": False}, {"consentimiento_firmado": False},
            {"fecha_consentimiento": None}, {"seccion_id": None},
        ):
            with self.subTest(changes=changes):
                self.change_student(**changes)
                response = self.send()
                self.assertEqual(response.status_code, 409)
                self.assertEqual(self.counts(), (0, 0, 0))
                self.change_student(
                    activo=True, consentimiento_firmado=True,
                    fecha_consentimiento=date(2026, 1, 1), seccion_id=1,
                )
        self.assertEqual(self.send().status_code, 200)

    def test_inactive_section_and_missing_student_are_rejected(self):
        with Session(self.engine) as session:
            section = session.get(Seccion, 1)
            section.activo = False
            session.add(section)
            session.commit()
        self.assertEqual(self.send().status_code, 409)
        self.assertEqual(self.send(self.payload(student_id=999)).status_code, 404)
        self.assertEqual(self.counts(), (0, 0, 0))

    def test_retries_confirm_one_record_without_recalculating_risk_or_level(self):
        for tipo in ("LECTURA", "FONOLOGIA"):
            with self.subTest(tipo=tipo):
                payload = self.payload(tipo, tipo=tipo)
                first = self.send(payload)
                self.assertEqual(first.status_code, 200, first.text)
                first_id = first.json()["synced"][0]["evaluacion_id"]
                payload["details"].reverse()
                again = self.send(payload)
                self.assertEqual(again.status_code, 200, again.text)
                self.assertEqual(again.json()["evaluations_inserted"], 0)
                self.assertEqual(again.json()["details_inserted"], 0)
                acknowledgement = again.json()["synced"][0]
                self.assertEqual(acknowledgement["evaluacion_id"], first_id)
                self.assertEqual(acknowledgement["details_confirmed"], 10)
        self.assertEqual(self.counts(), (2, 20, 2))
        self.assertEqual(self.predictor.call_count, 2)
        with Session(self.engine) as session:
            student = session.get(Estudiante, 1)
            self.assertEqual((student.nivel_lectura, student.nivel_fonologia), (1, 1))

    def test_different_sessions_still_apply_existing_adaptive_rules(self):
        self.assertEqual(self.send(self.payload("first")).status_code, 200)
        self.assertEqual(self.send(self.payload("second")).status_code, 200)
        with Session(self.engine) as session:
            self.assertEqual(session.get(Estudiante, 1).nivel_lectura, 2)
        self.assertEqual(self.counts(), (2, 20, 2))

    def test_changed_contents_under_same_identity_do_not_overwrite_data(self):
        payload = self.payload()
        self.assertEqual(self.send(payload).status_code, 200)
        payload["details"][0]["texto"] = "otro texto"
        self.assertEqual(self.send(payload).status_code, 409)
        self.assertEqual(self.counts(), (1, 10, 1))
        with Session(self.engine) as session:
            self.assertEqual(session.exec(select(DetalleEvaluacion)).first().texto, "ficticio")

    def test_already_received_data_can_be_acknowledged_after_deactivation(self):
        payload = self.payload()
        first = self.send(payload)
        self.assertEqual(first.status_code, 200)
        self.change_student(activo=False, consentimiento_firmado=False)
        acknowledgement = self.send(payload)
        self.assertEqual(acknowledgement.status_code, 200)
        self.assertEqual(acknowledgement.json()["evaluations_inserted"], 0)
        self.assertEqual(self.send(self.payload("not-received")).status_code, 409)
        self.assertEqual(self.counts(), (1, 10, 1))

    def test_incomplete_pending_and_mismatched_payloads_do_not_create_results(self):
        variants = []
        for count in (3, 8):
            payload = self.payload()
            payload["details"] = payload["details"][:count]
            variants.append(payload)
        for field, value in (
            ("total_items", 3), ("total_items", 10.0), ("sync_status", "PENDING"),
            ("estudiante_id", None), ("aciertos_primer_intento", 8),
            ("taps_erroneos_totales", 2), ("tiempo_promedio_ms", 99),
            ("total_media", 1), ("fecha_fin", "2020-01-01T00:00:00Z"),
        ):
            payload = self.payload()
            payload["sessions"][0][field] = value
            variants.append(payload)
        for field, value in (
            ("acierto", "true"), ("acierto", False), ("tiempo_respuesta_ms", -1),
            ("duracion_drag_drop_ms", -1), ("taps_erroneos", -1),
            ("tipo_prueba", "FONOLOGIA"), ("complejidad_estimulo", "OTRO"),
        ):
            payload = self.payload()
            payload["details"][0][field] = value
            variants.append(payload)
        repeated = self.payload()
        repeated["details"][1]["stimulus_id"] = repeated["details"][0]["stimulus_id"]
        variants.append(repeated)
        repeated = self.payload()
        repeated["details"][1]["local_detail_id"] = repeated["details"][0]["local_detail_id"]
        variants.append(repeated)
        repeated = self.payload()
        repeated["sessions"].append(copy.deepcopy(repeated["sessions"][0]))
        variants.append(repeated)
        orphan = self.payload()
        orphan["details"][0]["local_session_id"] = "absent"
        variants.append(orphan)
        for index, payload in enumerate(variants):
            with self.subTest(variant=index):
                self.assertEqual(self.send(payload).status_code, 422)
        self.assertEqual(self.counts(), (0, 0, 0))
        self.predictor.assert_not_called()

    def test_positive_half_millisecond_matches_dart_rounding(self):
        payload = self.payload()
        for detail in payload["details"][:5]:
            detail["tiempo_respuesta_ms"] = 1001
        payload["sessions"][0]["tiempo_promedio_ms"] = 1001
        self.assertEqual(self.send(payload).status_code, 200)

    def test_batch_is_rolled_back_if_later_session_conflicts(self):
        original = self.payload("received")
        self.assertEqual(self.send(original).status_code, 200)
        changed = copy.deepcopy(original)
        changed["details"][0]["texto"] = "conflicto"
        new = self.payload("new")
        response = self.send({
            "sessions": new["sessions"] + changed["sessions"],
            "details": new["details"] + changed["details"],
        })
        self.assertEqual(response.status_code, 409)
        self.assertEqual(self.counts(), (1, 10, 1))
        with Session(self.engine) as session:
            self.assertEqual(session.get(Estudiante, 1).nivel_lectura, 1)

    def test_database_failure_does_not_leave_partial_evaluations(self):
        failure = OperationalError("test statement", {}, RuntimeError("local test failure"))
        with patch("app.api.evaluaciones.update_student_level_for_test_type", side_effect=failure):
            response = self.send()
        self.assertEqual(response.status_code, 503)
        self.assertEqual(self.counts(), (0, 0, 0))
        self.assertEqual(self.send().status_code, 200)

    def test_unique_collision_retries_and_confirms_existing_record(self):
        first = self.send().json()
        collision = IntegrityError(
            None, None, sqlite3.IntegrityError(
                "UNIQUE constraint failed: evaluaciones.local_session_id"
            ),
        )
        from app.schemas.evaluation_sync import EvaluationSyncResponse
        confirmed = EvaluationSyncResponse.model_validate(first)
        with patch("app.api.evaluaciones._save_sync_batch", side_effect=[collision, confirmed]) as save:
            self.assertEqual(self.send().status_code, 200)
            self.assertEqual(save.call_count, 2)
        self.assertEqual(self.counts(), (1, 10, 1))

    def test_database_enforces_unique_session_identity(self):
        indexes = inspect(self.engine).get_indexes("evaluaciones")
        self.assertTrue(any(
            item["unique"] and item["column_names"] == ["local_session_id"]
            for item in indexes
        ))
        self.assertEqual(self.send().status_code, 200)
        with Session(self.engine) as session:
            session.add(Evaluacion(local_session_id="session-a"))
            with self.assertRaises(IntegrityError):
                session.commit()
            session.rollback()
        self.assertEqual(self.counts(), (1, 10, 1))
