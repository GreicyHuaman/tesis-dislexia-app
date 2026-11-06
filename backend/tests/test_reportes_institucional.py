import unittest
from datetime import date

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.api.reportes import router
from app.core.security import get_current_user
from app.db.session import get_session
from app.models.evaluation import Evaluacion
from app.models.section import Seccion
from app.models.student import Estudiante
from app.models.user import Usuario


URL = "/api/v1/reportes/resumen-institucional"


class InstitutionalReportTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        SQLModel.metadata.create_all(self.engine)
        self.app = FastAPI()
        self.app.include_router(router)

        def local_session():
            with Session(self.engine) as session:
                yield session

        self.user = Usuario(
            id=1,
            nombres="Director",
            apellidos="Prueba",
            email="director@edu.com",
            rol="DIRECTORA",
            password_hash="unused-in-test",
        )
        self.app.dependency_overrides[get_session] = local_session
        self.app.dependency_overrides[get_current_user] = lambda: self.user
        self.client = TestClient(self.app)
        self.addCleanup(self.engine.dispose)
        self.addCleanup(self.client.close)

    def seed(self):
        with Session(self.engine) as session:
            session.add_all([
                Seccion(id=1, grado=3, nombre="A", activo=True),
                Seccion(id=2, grado=3, nombre="B", activo=False),
                Seccion(id=3, grado=4, nombre="C", activo=True),
            ])
            session.add_all([
                Estudiante(
                    id=index,
                    nombres="Estudiante",
                    apellidos=f"Prueba {index}",
                    fecha_nacimiento=date(2017, 1, 1),
                    seccion_id=section,
                    activo=active,
                )
                for index, section, active in [
                    (1, 1, True), (2, 2, False), (3, 1, True),
                    (4, 1, False), (5, 3, True),
                ]
            ])
            session.add_all([
                Evaluacion(estudiante_id=1, tipo_prueba="LECTURA", semaforo="VERDE"),
                Evaluacion(estudiante_id=1, tipo_prueba="FONOLOGIA", semaforo="ROJO"),
                Evaluacion(estudiante_id=2, tipo_prueba="LECTURA", semaforo="AMARILLO"),
                Evaluacion(estudiante_id=5, tipo_prueba="LECTURA", semaforo="VERDE"),
            ])
            session.commit()

    def summary(self, url=URL):
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_cp032_counts_all_records_including_inactive(self):
        self.seed()
        self.assertEqual(self.summary(), {
            "total_secciones": 3,
            "secciones_activas": 2,
            "secciones_inactivas": 1,
            "total_estudiantes": 5,
            "estudiantes_activos": 3,
            "estudiantes_inactivos": 2,
            "total_evaluaciones": 4,
            "estudiantes_con_evaluaciones": 3,
            "estudiantes_sin_evaluaciones": 2,
        })

    def test_institutional_summary_ignores_history_filters(self):
        self.seed()
        self.assertEqual(
            self.summary(f"{URL}?tipo_prueba=LECTURA&semaforo=ROJO&estudiante_id=1"),
            self.summary(),
        )

    def test_grade_scope_includes_inactive_sections_of_allowed_grade(self):
        self.seed()
        self.user.grado_scope = 3
        self.assertEqual(self.summary(), {
            "total_secciones": 2,
            "secciones_activas": 1,
            "secciones_inactivas": 1,
            "total_estudiantes": 4,
            "estudiantes_activos": 2,
            "estudiantes_inactivos": 2,
            "total_evaluaciones": 3,
            "estudiantes_con_evaluaciones": 2,
            "estudiantes_sin_evaluaciones": 2,
        })

    def test_no_sections_in_scope_returns_real_zero_counts(self):
        self.seed()
        self.user.grado_scope = 9
        self.assertTrue(all(value == 0 for value in self.summary().values()))

    def test_empty_institution_has_zero_counts(self):
        data = self.summary()
        self.assertEqual(len(data), 9)
        self.assertTrue(all(value == 0 for value in data.values()))

    def test_student_without_section_is_counted_without_global_scope_filter(self):
        self.seed()
        with Session(self.engine) as session:
            session.add(Estudiante(nombres="Sin", apellidos="Seccion", activo=False))
            session.commit()
        data = self.summary()
        self.assertEqual(data["total_estudiantes"], 6)
        self.assertEqual(data["estudiantes_inactivos"], 3)
        self.assertEqual(data["estudiantes_sin_evaluaciones"], 3)
        self.user.grado_scope = 3
        self.assertEqual(self.summary()["total_estudiantes"], 4)

    def test_legacy_evaluations_do_not_inflate_evaluated_students(self):
        self.seed()
        with Session(self.engine) as session:
            session.add_all([
                Evaluacion(estudiante_id=None),
                Evaluacion(estudiante_id=999),
            ])
            session.commit()
        data = self.summary()
        self.assertEqual(data["total_evaluaciones"], 6)
        self.assertEqual(data["estudiantes_con_evaluaciones"], 3)
        self.assertEqual(data["estudiantes_sin_evaluaciones"], 2)

    def test_counts_students_even_without_any_evaluations(self):
        with Session(self.engine) as session:
            session.add_all([
                Estudiante(nombres="Estudiante", apellidos=f"Prueba {index}")
                for index in range(1001)
            ])
            session.commit()
        data = self.summary()
        self.assertEqual(data["total_estudiantes"], 1001)
        self.assertEqual(data["estudiantes_sin_evaluaciones"], 1001)
        self.assertEqual(data["total_evaluaciones"], 0)

    def test_only_director_can_read_summary(self):
        for role in ("MAESTRO", "PSICOLOGA", "ESTUDIANTE"):
            with self.subTest(role=role):
                self.user.rol = role
                self.assertEqual(self.client.get(URL).status_code, 403)

    def test_summary_requires_authentication(self):
        del self.app.dependency_overrides[get_current_user]
        self.assertEqual(self.client.get(URL).status_code, 401)

    def test_read_does_not_change_records(self):
        self.seed()
        for _ in range(2):
            self.summary()
        with Session(self.engine) as session:
            self.assertEqual(len(session.exec(select(Seccion)).all()), 3)
            self.assertEqual(len(session.exec(select(Estudiante)).all()), 5)
            self.assertEqual(len(session.exec(select(Evaluacion)).all()), 4)

    def test_all_counts_use_a_single_sql_statement(self):
        self.seed()
        selects = []

        def record_select(connection, cursor, statement, parameters, context, executemany):
            if statement.lstrip().upper().startswith("SELECT"):
                selects.append(True)

        event.listen(self.engine, "before_cursor_execute", record_select)
        self.addCleanup(event.remove, self.engine, "before_cursor_execute", record_select)
        self.summary()
        self.assertEqual(len(selects), 1)

    def test_existing_report_summary_keeps_history_filters(self):
        self.seed()
        response = self.client.get(
            "/api/v1/reportes/resumen-semaforo",
            params={"estudiante_id": 1, "tipo_prueba": "LECTURA"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["total_evaluaciones"], 1)
        self.assertEqual(self.summary()["total_evaluaciones"], 4)


if __name__ == "__main__":
    unittest.main()
