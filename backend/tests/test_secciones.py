import unittest
from datetime import date

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.api.docente_seccion import router as assignments_router
from app.api.estudiantes import router as students_router
from app.api.jornadas_evaluacion import router as jornadas_router
from app.api.secciones import router
from app.core.security import get_current_user
from app.db.session import get_session
from app.models.jornada import JornadaEvaluacion
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario


class SectionApiTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        SQLModel.metadata.create_all(self.engine)
        app = FastAPI()
        app.include_router(router)
        app.include_router(assignments_router)
        app.include_router(students_router)
        app.include_router(jornadas_router)

        def local_session():
            with Session(self.engine) as session:
                yield session

        self.current_user = Usuario(
            id=1,
            nombres="Director",
            apellidos="Prueba",
            email="director@edu.com",
            rol="DIRECTORA",
            password_hash="unused-in-test",
        )
        app.dependency_overrides[get_session] = local_session
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.client = TestClient(app)
        self.addCleanup(self.engine.dispose)
        self.addCleanup(self.client.close)

    def section_count(self):
        with Session(self.engine) as session:
            return len(session.exec(select(Seccion)).all())

    def create_section(self, **overrides):
        payload = {"grado": 3, "nombre": "A", "turno": "MAÑANA"}
        payload.update(overrides)
        return self.client.post("/api/v1/secciones", json=payload)

    def seed_assignments(self):
        director = self.current_user
        teacher = Usuario(
            id=2, nombres="Jessica", apellidos="Linares",
            email="jessica@edu.com", rol="MAESTRO", password_hash="unused-in-test",
        )
        other_teacher = Usuario(
            id=3, nombres="Otro", apellidos="Docente",
            email="otro@edu.com", rol="MAESTRO", password_hash="unused-in-test",
        )
        with Session(self.engine) as session:
            session.add_all([director, teacher, other_teacher])
            session.commit()
            for user in (director, teacher, other_teacher):
                session.refresh(user)

        sections = {}
        for name in ("A", "B", "C", "D", "E", "X", "Z"):
            response = self.create_section(nombre=name)
            self.assertEqual(response.status_code, 200, response.text)
            sections[name] = response.json()["id"]

        link = self.assign_teacher(teacher.id, sections["X"])
        self.assign_teacher(other_teacher.id, sections["A"])
        return director, teacher, other_teacher, sections, link

    def assign_teacher(self, user_id, section_id):
        response = self.client.post(
            "/api/v1/admin/docente-seccion",
            json={"usuario_id": user_id, "seccion_id": section_id},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["id"]

    def visible_section_ids(self):
        response = self.client.get("/api/v1/secciones")
        self.assertEqual(response.status_code, 200, response.text)
        return [section["id"] for section in response.json()]

    def test_cp006_teacher_only_sees_assigned_section(self):
        _, teacher, _, sections, _ = self.seed_assignments()
        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [sections["X"]])

    def test_cp037_assigned_3e_without_jornada_does_not_authorize_3d(self):
        _, teacher, _, sections, old_link = self.seed_assignments()
        response = self.client.delete(f"/api/v1/admin/docente-seccion/{old_link}")
        self.assertEqual(response.status_code, 200, response.text)
        self.assign_teacher(teacher.id, sections["E"])

        response = self.client.post(
            "/api/v1/jornadas-evaluacion/activar",
            json={"seccion_id": sections["D"]},
        )
        self.assertEqual(response.status_code, 200, response.text)
        foreign_jornada = response.json()

        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [sections["E"]])
        response = self.client.get(
            f"/api/v1/jornadas-evaluacion/activa/{sections['E']}"
        )
        self.assertEqual(response.status_code, 404, response.text)
        self.assertEqual(response.json()["detail"], "No hay jornada activa para esta sección.")
        response = self.client.get(
            f"/api/v1/jornadas-evaluacion/activa/{sections['D']}"
        )
        self.assertEqual(response.status_code, 403, response.text)
        self.assertNotIn("id", response.json())
        response = self.client.post(
            "/api/v1/jornadas-evaluacion/activar",
            json={"seccion_id": sections["D"]},
        )
        self.assertEqual(response.status_code, 403, response.text)
        self.assertEqual(self.client.get("/api/v1/jornadas-evaluacion").json(), [])
        with Session(self.engine) as session:
            jornadas = session.exec(select(JornadaEvaluacion)).all()
            self.assertEqual(len(jornadas), 1)
            self.assertEqual(jornadas[0].id, foreign_jornada["id"])
            self.assertEqual(jornadas[0].estado, "ACTIVA")

        response = self.client.post(
            "/api/v1/jornadas-evaluacion/activar",
            json={"seccion_id": sections["E"]},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["seccion_id"], sections["E"])
        response = self.client.get(
            f"/api/v1/jornadas-evaluacion/activa/{sections['E']}"
        )
        self.assertEqual(response.status_code, 200, response.text)
        response = self.client.get("/api/v1/jornadas-evaluacion")
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(
            [jornada["seccion_id"] for jornada in response.json()], [sections["E"]],
        )

    def test_director_and_psychologist_keep_institutional_visibility(self):
        director, _, _, sections, _ = self.seed_assignments()
        for role in ("DIRECTORA", "PSICOLOGA"):
            with self.subTest(role=role):
                director.rol = role
                self.current_user = director
                self.assertEqual(self.visible_section_ids(), list(sections.values()))

    def test_teacher_without_assignments_sees_no_sections(self):
        director, teacher, _, _, link = self.seed_assignments()
        self.current_user = director
        response = self.client.delete(f"/api/v1/admin/docente-seccion/{link}")
        self.assertEqual(response.status_code, 200, response.text)
        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [])

    def test_inactive_assigned_sections_are_not_offered_to_teacher(self):
        director, teacher, _, sections, _ = self.seed_assignments()
        self.current_user = director
        response = self.client.patch(
            f"/api/v1/secciones/{sections['X']}", json={"activo": False}
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [])

    def test_multiple_assignments_are_sorted_and_not_duplicated(self):
        _, teacher, _, sections, _ = self.seed_assignments()
        self.assign_teacher(teacher.id, sections["Z"])
        with Session(self.engine) as session:
            session.add(DocenteSeccion(usuario_id=teacher.id, seccion_id=sections["X"]))
            session.commit()
        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [sections["X"], sections["Z"]])

    def test_changed_assignment_updates_teacher_visibility(self):
        _, teacher, _, sections, link = self.seed_assignments()
        response = self.client.delete(f"/api/v1/admin/docente-seccion/{link}")
        self.assertEqual(response.status_code, 200, response.text)
        self.assign_teacher(teacher.id, sections["Z"])
        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [sections["Z"]])

    def test_switching_teachers_does_not_share_section_scope(self):
        _, teacher, other_teacher, sections, _ = self.seed_assignments()
        self.current_user = teacher
        self.assertEqual(self.visible_section_ids(), [sections["X"]])
        self.current_user = other_teacher
        self.assertEqual(self.visible_section_ids(), [sections["A"]])

    def test_teacher_still_cannot_manage_unassigned_section(self):
        _, teacher, _, sections, _ = self.seed_assignments()
        self.current_user = teacher
        response = self.client.post(
            "/api/v1/estudiantes",
            json={
                "nombres": "Estudiante", "apellidos": "Prueba",
                "fecha_nacimiento": date(
                    date.today().year - 9, 1, 1
                ).isoformat(),
                "seccion_id": sections["A"],
                "consentimiento_firmado": True,
                "fecha_consentimiento": "2026-11-04",
            },
        )
        self.assertEqual(response.status_code, 403, response.text)
        with Session(self.engine) as session:
            self.assertEqual(list(session.exec(select(Estudiante)).all()), [])
        response = self.client.post(
            "/api/v1/jornadas-evaluacion/activar",
            json={"seccion_id": sections["A"]},
        )
        self.assertEqual(response.status_code, 403, response.text)
        response = self.client.get(
            f"/api/v1/jornadas-evaluacion/activa/{sections['A']}"
        )
        self.assertEqual(response.status_code, 403, response.text)
        response = self.client.post(
            "/api/v1/jornadas-evaluacion/activar",
            json={"seccion_id": sections["X"]},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["seccion_id"], sections["X"])

    def test_create_normalizes_name_and_allowed_shifts(self):
        for index, (turno, expected) in enumerate(
            ((" mañana ", "MAÑANA"), ("MANANA", "MAÑANA"), (" tarde ", "TARDE"))
        ):
            with self.subTest(turno=turno):
                response = self.create_section(nombre=f" s{index} ", turno=turno)
                self.assertEqual(response.status_code, 200, response.text)
                self.assertEqual(response.json()["grado"], 3)
                self.assertEqual(response.json()["nombre"], f"S{index}")
                self.assertEqual(response.json()["turno"], expected)
                self.assertTrue(response.json()["activo"])
        self.assertEqual(self.section_count(), 3)

    def test_create_defaults_to_third_grade(self):
        response = self.client.post(
            "/api/v1/secciones", json={"nombre": "A", "turno": "TARDE"}
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["grado"], 3)

    def test_invalid_grades_do_not_create_sections(self):
        for grado in (4, 5, 0, None, True, 3.5, "tercero"):
            with self.subTest(grado=grado):
                response = self.create_section(grado=grado)
                self.assertEqual(response.status_code, 422, response.text)
                self.assertEqual(self.section_count(), 0)

    def test_missing_shift_does_not_create_section(self):
        response = self.client.post(
            "/api/v1/secciones", json={"grado": 3, "nombre": "A"}
        )
        self.assertEqual(response.status_code, 422, response.text)
        self.assertEqual(self.section_count(), 0)

    def test_invalid_shifts_do_not_create_sections(self):
        for turno in (None, "", "  ", "turno mañana", "NOCHE", 1):
            with self.subTest(turno=turno):
                response = self.create_section(turno=turno)
                self.assertEqual(response.status_code, 422, response.text)
                self.assertEqual(self.section_count(), 0)

    def test_blank_names_do_not_create_sections(self):
        for nombre in ("", "  ", None):
            with self.subTest(nombre=nombre):
                response = self.create_section(nombre=nombre)
                self.assertEqual(response.status_code, 422, response.text)
                self.assertEqual(self.section_count(), 0)

    def test_section_is_listed_with_persisted_grade_and_shift(self):
        section = self.create_section(turno="tarde").json()
        response = self.client.get("/api/v1/secciones")
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json(), [section])
        with Session(self.engine) as session:
            stored = session.get(Seccion, section["id"])
            self.assertEqual(stored.grado, 3)
            self.assertEqual(stored.turno, "TARDE")

    def test_duplicate_section_is_still_rejected(self):
        self.assertEqual(self.create_section().status_code, 200)
        response = self.create_section(nombre=" a ")
        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(self.section_count(), 1)

    def test_update_normalizes_shift_and_preserves_partial_updates(self):
        section_id = self.create_section().json()["id"]
        response = self.client.patch(
            f"/api/v1/secciones/{section_id}", json={"turno": " tarde "}
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["turno"], "TARDE")
        response = self.client.patch(
            f"/api/v1/secciones/{section_id}", json={"activo": False}
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["grado"], 3)
        self.assertEqual(response.json()["turno"], "TARDE")
        self.assertFalse(response.json()["activo"])

    def test_invalid_update_does_not_modify_section(self):
        original = self.create_section().json()
        for payload in (
            {"grado": 4},
            {"grado": 5},
            {"grado": None},
            {"turno": ""},
            {"turno": None},
            {"turno": "NOCHE"},
            {"nombre": " ", "turno": "TARDE"},
        ):
            with self.subTest(payload=payload):
                response = self.client.patch(
                    f"/api/v1/secciones/{original['id']}", json=payload
                )
                self.assertEqual(response.status_code, 422, response.text)
                listed = self.client.get("/api/v1/secciones").json()
                self.assertEqual(listed, [original])

    def test_teacher_cannot_create_or_edit_sections(self):
        section_id = self.create_section().json()["id"]
        self.current_user.rol = "MAESTRO"
        response = self.create_section(nombre="B")
        self.assertEqual(response.status_code, 403, response.text)
        response = self.client.patch(
            f"/api/v1/secciones/{section_id}", json={"turno": "TARDE"}
        )
        self.assertEqual(response.status_code, 403, response.text)
        self.assertEqual(self.section_count(), 1)


if __name__ == "__main__":
    unittest.main()
