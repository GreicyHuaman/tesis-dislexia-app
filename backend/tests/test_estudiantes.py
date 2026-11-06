import csv
import io
import unittest
from datetime import date, datetime, timedelta, timezone
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from openpyxl import Workbook
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.api.estudiantes import router
from app.core.security import get_current_user
from app.db.session import get_session
from app.models.jornada import JornadaEvaluacion
from app.models.section import DocenteSeccion, Seccion
from app.models.student import Estudiante
from app.models.user import Usuario
from app.schemas.student_schema import validate_student_birth_date


class StudentApiTests(unittest.TestCase):
    today = date(2026, 11, 4)

    def setUp(self):
        clock = patch("app.schemas.student_schema.datetime", wraps=datetime)
        self.mock_datetime = clock.start()
        self.mock_datetime.now.return_value = datetime(
            2026, 11, 4, 12, tzinfo=timezone(timedelta(hours=-5))
        )
        self.addCleanup(clock.stop)
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        SQLModel.metadata.create_all(self.engine)
        self.addCleanup(self.engine.dispose)
        with Session(self.engine) as session:
            session.add(Seccion(id=1, grado=3, nombre="X", turno="MAÑANA"))
            session.commit()

        self.current_user = Usuario(
            id=1, nombres="Director", apellidos="Prueba",
            email="director@edu.com", rol="DIRECTORA",
            password_hash="unused-in-test",
        )

        def local_session():
            with Session(self.engine) as session:
                yield session

        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_session] = local_session
        app.dependency_overrides[get_current_user] = lambda: self.current_user
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def create_student(self, **overrides):
        payload = {
            "nombres": "María José",
            "apellidos": "Huamán O'Connor",
            "fecha_nacimiento": "2018-11-04",
            "seccion_id": 1,
            "consentimiento_firmado": True,
            "fecha_consentimiento": self.today.isoformat(),
            "activo": True,
        }
        payload.update(overrides)
        return self.client.post("/api/v1/estudiantes", json=payload)

    def stored_students(self):
        with Session(self.engine) as session:
            return list(session.exec(select(Estudiante)).all())

    def import_rows(self, rows, *, xlsx=False):
        columns = [
            "nombres", "apellidos", "fecha_nacimiento", "grado", "seccion",
            "consentimiento_firmado", "fecha_consentimiento", "activo",
        ]
        data = []
        for row in rows:
            values = {
                "nombres": "María José", "apellidos": "Huamán O'Connor",
                "fecha_nacimiento": "2018-11-04", "grado": 3, "seccion": "X",
                "consentimiento_firmado": "SI",
                "fecha_consentimiento": self.today.isoformat(), "activo": "SI",
            }
            values.update(row)
            data.append(values)
        if xlsx:
            workbook = Workbook()
            sheet = workbook.active
            sheet.append(columns)
            for row in data:
                sheet.append([row[column] for column in columns])
            stream = io.BytesIO()
            workbook.save(stream)
            workbook.close()
            contents = stream.getvalue()
            filename = "estudiantes.xlsx"
        else:
            stream = io.StringIO()
            writer = csv.DictWriter(stream, fieldnames=columns)
            writer.writeheader()
            writer.writerows(data)
            contents = stream.getvalue().encode("utf-8")
            filename = "estudiantes.csv"
        response = self.client.post(
            "/api/v1/estudiantes/importar",
            files={"file": (filename, contents)},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_cp007_valid_student_keeps_consent_activity_and_pin(self):
        for birth_date in ("2018-11-04", "2017-11-04", "2016-11-05"):
            with self.subTest(birth_date=birth_date):
                response = self.create_student(fecha_nacimiento=birth_date)
                self.assertEqual(response.status_code, 200, response.text)
                student = response.json()
                self.assertTrue(student["activo"])
                self.assertTrue(student["consentimiento_firmado"])
                self.assertEqual(student["fecha_nacimiento"], birth_date)
                self.assertEqual(student["fecha_consentimiento"], "2026-11-04")
                self.assertEqual(student["seccion_id"], 1)
                self.assertRegex(student["pin_corto"], r"^\d{4}$")
        students = self.stored_students()
        self.assertEqual(len(students), 3)
        self.assertEqual(len({student.pin_corto for student in students}), 3)

    def test_names_are_trimmed_without_rejecting_accents_or_apostrophes(self):
        response = self.create_student(
            nombres="  María José  ", apellidos="  Huamán O'Connor  "
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["nombres"], "María José")
        self.assertEqual(response.json()["apellidos"], "Huamán O'Connor")

    def test_missing_names_and_birth_date_are_rejected(self):
        for field in ("nombres", "apellidos", "fecha_nacimiento"):
            with self.subTest(field=field):
                payload = {
                    "nombres": "Estudiante", "apellidos": "Prueba",
                    "fecha_nacimiento": "2018-11-04", "seccion_id": 1,
                    "consentimiento_firmado": True,
                    "fecha_consentimiento": self.today.isoformat(),
                }
                del payload[field]
                response = self.client.post("/api/v1/estudiantes", json=payload)
                self.assertEqual(response.status_code, 422, response.text)
                self.assertEqual(self.stored_students(), [])

    def test_empty_null_and_whitespace_names_do_not_generate_a_pin(self):
        with patch("app.api.estudiantes._generate_pin_for_student") as generate_pin:
            for field in ("nombres", "apellidos"):
                for value in ("", " \t\n ", None):
                    with self.subTest(field=field, value=value):
                        response = self.create_student(**{field: value})
                        self.assertEqual(response.status_code, 422, response.text)
                        self.assertEqual(self.stored_students(), [])
            generate_pin.assert_not_called()

    def test_invalid_birth_dates_do_not_generate_a_pin(self):
        for birth_date in (
            None, "", "texto", "2018-02-30", "2018-11-05", "2016-11-04",
            "2006-01-01", "2026-11-05",
        ):
            with self.subTest(birth_date=birth_date):
                with patch("app.api.estudiantes._generate_pin_for_student") as pin:
                    response = self.create_student(fecha_nacimiento=birth_date)
                    self.assertEqual(response.status_code, 422, response.text)
                    self.assertEqual(self.stored_students(), [])
                    pin.assert_not_called()

    def test_birth_date_range_uses_completed_years_including_leap_birthdays(self):
        cases = (
            (date(2032, 2, 28), False),
            (date(2032, 2, 29), True),
            (date(2034, 2, 28), True),
            (date(2034, 3, 1), False),
        )
        for today, accepted in cases:
            with self.subTest(today=today):
                self.mock_datetime.now.return_value = datetime(
                    today.year, today.month, today.day, 12,
                    tzinfo=timezone(timedelta(hours=-5)),
                )
                if accepted:
                    self.assertEqual(
                        validate_student_birth_date(date(2024, 2, 29)),
                        date(2024, 2, 29),
                    )
                else:
                    with self.assertRaises(ValueError):
                        validate_student_birth_date(date(2024, 2, 29))

    def test_age_is_calculated_using_lima_date(self):
        validate_student_birth_date(date(2018, 11, 4))
        self.mock_datetime.now.assert_called_with(timezone(timedelta(hours=-5)))

    def test_active_creation_still_requires_consent_and_its_date(self):
        for payload in (
            {"consentimiento_firmado": False},
            {"fecha_consentimiento": None},
        ):
            with self.subTest(payload=payload):
                response = self.create_student(**payload)
                self.assertEqual(response.status_code, 400, response.text)
                self.assertEqual(self.stored_students(), [])

    def test_cp050_inactive_creation_without_consent_ignores_date_and_pin(self):
        with patch("app.api.estudiantes._generate_pin_for_student") as generate_pin:
            for consent_date in (None, self.today.isoformat()):
                with self.subTest(consent_date=consent_date):
                    response = self.create_student(
                        activo=False,
                        consentimiento_firmado=False,
                        fecha_consentimiento=consent_date,
                        pin_corto="2468",
                    )
                    self.assertEqual(response.status_code, 200, response.text)
                    student = response.json()
                    self.assertFalse(student["activo"])
                    self.assertFalse(student["consentimiento_firmado"])
                    self.assertIsNone(student["fecha_consentimiento"])
                    self.assertIsNone(student["pin_corto"])
            generate_pin.assert_not_called()
        self.assertEqual(len(self.stored_students()), 2)
        for student in self.stored_students():
            self.assertFalse(student.activo)
            self.assertIsNone(student.pin_corto)
            self.assertIsNone(student.fecha_consentimiento)

    def test_cp050_teacher_can_only_create_inactive_in_assigned_section(self):
        self.current_user.rol = "MAESTRO"
        with Session(self.engine) as session:
            session.add(DocenteSeccion(usuario_id=1, seccion_id=1))
            session.add(Seccion(id=2, grado=3, nombre="D", turno="MAÑANA"))
            session.commit()
        response = self.create_student(activo=False, consentimiento_firmado=False)
        self.assertEqual(response.status_code, 200, response.text)
        response = self.create_student(
            activo=False, consentimiento_firmado=False, seccion_id=2,
        )
        self.assertEqual(response.status_code, 403, response.text)
        self.assertEqual(len(self.stored_students()), 1)

    def test_cp050_inactive_record_can_be_edited_but_not_activated_without_consent(self):
        original = self.create_student(
            activo=False, consentimiento_firmado=False,
        ).json()
        path = f"/api/v1/estudiantes/{original['id']}"
        response = self.client.patch(path, json={
            "nombres": "Nombre actualizado", "activo": False,
            "consentimiento_firmado": False, "fecha_consentimiento": None,
        })
        self.assertEqual(response.status_code, 200, response.text)
        self.assertIsNone(response.json()["pin_corto"])
        with patch("app.api.estudiantes._generate_pin_for_student") as generate_pin:
            response = self.client.patch(path, json={
                "activo": True, "nombres": "Cambio rechazado",
            })
            self.assertEqual(response.status_code, 400, response.text)
            self.assertEqual(
                response.json()["detail"],
                "Para activar al estudiante se requiere consentimiento informado firmado.",
            )
            generate_pin.assert_not_called()
        stored = self.stored_students()[0]
        self.assertEqual(stored.nombres, "Nombre actualizado")
        self.assertFalse(stored.activo)
        self.assertFalse(stored.consentimiento_firmado)
        self.assertIsNone(stored.pin_corto)

    def test_cp050_consent_and_date_are_required_before_activation_generates_pin(self):
        original = self.create_student(
            activo=False, consentimiento_firmado=False,
        ).json()
        path = f"/api/v1/estudiantes/{original['id']}"
        with patch("app.api.estudiantes._generate_pin_for_student") as generate_pin:
            for payload in (
                {"consentimiento_firmado": True, "activo": True},
                {
                    "consentimiento_firmado": True,
                    "fecha_consentimiento": None, "activo": True,
                },
            ):
                with self.subTest(payload=payload):
                    response = self.client.patch(path, json=payload)
                    self.assertEqual(response.status_code, 400, response.text)
            generate_pin.assert_not_called()
        response = self.client.patch(path, json={
            "consentimiento_firmado": True,
            "fecha_consentimiento": self.today.isoformat(), "activo": True,
        })
        self.assertEqual(response.status_code, 200, response.text)
        student = response.json()
        self.assertTrue(student["activo"])
        self.assertTrue(student["consentimiento_firmado"])
        self.assertRegex(student["pin_corto"], r"^\d{4}$")
        self.assertEqual(
            self.client.get(f"/api/v1/estudiantes/pin/{student['pin_corto']}").status_code,
            200,
        )
        cache = self.client.get("/api/v1/estudiantes/offline-cache")
        self.assertEqual(cache.status_code, 200, cache.text)
        self.assertEqual([item["id"] for item in cache.json()], [student["id"]])

    def test_consent_can_be_recorded_without_activating_then_pin_is_preserved(self):
        original = self.create_student(
            activo=False, consentimiento_firmado=False,
        ).json()
        path = f"/api/v1/estudiantes/{original['id']}"
        response = self.client.patch(path, json={
            "consentimiento_firmado": True,
            "fecha_consentimiento": self.today.isoformat(),
        })
        self.assertEqual(response.status_code, 200, response.text)
        student = response.json()
        self.assertFalse(student["activo"])
        self.assertRegex(student["pin_corto"], r"^\d{4}$")
        self.assertEqual(
            self.client.get(f"/api/v1/estudiantes/pin/{student['pin_corto']}").status_code,
            404,
        )
        self.assertEqual(self.client.get("/api/v1/estudiantes/offline-cache").json(), [])
        response = self.client.patch(path, json={"activo": True})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["pin_corto"], student["pin_corto"])

    def test_cp050_no_pin_regeneration_or_cache_without_consent(self):
        student = self.create_student(
            activo=False, consentimiento_firmado=False,
        ).json()
        with patch("app.api.estudiantes._generate_pin_for_student") as generate_pin:
            response = self.client.post(
                f"/api/v1/estudiantes/{student['id']}/regenerar-pin",
            )
            self.assertEqual(response.status_code, 400, response.text)
            generate_pin.assert_not_called()
        self.assertEqual(self.client.get("/api/v1/estudiantes/offline-cache").json(), [])
        with Session(self.engine) as session:
            record = session.get(Estudiante, student["id"])
            record.pin_corto = "2468"
            session.add(record)
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            session.add(JornadaEvaluacion(
                seccion_id=1, responsable_id=1, estado="ACTIVA",
                fecha_inicio=now,
                fecha_expiracion=now + timedelta(hours=8),
            ))
            session.commit()
        self.assertEqual(
            self.client.get("/api/v1/estudiantes/pin/2468").status_code, 404,
        )
        self.assertEqual(
            self.client.get("/api/v1/estudiantes/modo-aula/1/pin/2468").status_code, 404,
        )

    def test_signed_consent_date_cannot_be_cleared_without_revoking_consent(self):
        original = self.create_student().json()
        response = self.client.patch(
            f"/api/v1/estudiantes/{original['id']}",
            json={"fecha_consentimiento": None},
        )
        self.assertEqual(response.status_code, 400, response.text)
        self.assertEqual(
            self.stored_students()[0].fecha_consentimiento.isoformat(),
            original["fecha_consentimiento"],
        )

    def test_import_still_stores_inactive_records_without_consent(self):
        for xlsx in (False, True):
            with self.subTest(xlsx=xlsx):
                result = self.import_rows([{
                    "nombres": f"Pendiente {xlsx}", "consentimiento_firmado": "NO",
                    "fecha_consentimiento": "", "activo": "NO",
                }], xlsx=xlsx)
                self.assertEqual(result["created_count"], 1)
                self.assertEqual(result["error_count"], 0)
        self.assertEqual(len(self.stored_students()), 2)
        for student in self.stored_students():
            self.assertFalse(student.activo)
            self.assertFalse(student.consentimiento_firmado)
            self.assertIsNone(student.fecha_consentimiento)
            self.assertIsNone(student.pin_corto)

    def test_invalid_updates_leave_student_and_pin_unchanged(self):
        original = self.create_student().json()
        for payload in (
            {"nombres": ""}, {"nombres": "  "}, {"nombres": None},
            {"apellidos": ""}, {"apellidos": "  "}, {"apellidos": None},
            {"fecha_nacimiento": None}, {"fecha_nacimiento": ""},
            {"fecha_nacimiento": "2006-01-01"},
            {"fecha_nacimiento": "2018-11-05"},
            {"fecha_nacimiento": (self.today + timedelta(days=1)).isoformat()},
        ):
            with self.subTest(payload=payload):
                response = self.client.patch(
                    f"/api/v1/estudiantes/{original['id']}", json=payload
                )
                self.assertEqual(response.status_code, 422, response.text)
                current = self.stored_students()[0]
                self.assertEqual(current.nombres, original["nombres"])
                self.assertEqual(current.apellidos, original["apellidos"])
                self.assertEqual(
                    current.fecha_nacimiento.isoformat(), original["fecha_nacimiento"]
                )
                self.assertEqual(current.pin_corto, original["pin_corto"])

    def test_valid_and_partial_updates_preserve_pin_and_consent_rules(self):
        original = self.create_student().json()
        response = self.client.patch(
            f"/api/v1/estudiantes/{original['id']}",
            json={"nombres": "  Nombre actualizado  ", "fecha_nacimiento": "2017-11-04"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["nombres"], "Nombre actualizado")
        self.assertEqual(response.json()["pin_corto"], original["pin_corto"])
        response = self.client.patch(
            f"/api/v1/estudiantes/{original['id']}",
            json={"consentimiento_firmado": False},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertFalse(response.json()["activo"])
        self.assertIsNone(response.json()["pin_corto"])
        self.assertIsNone(response.json()["fecha_consentimiento"])
        response = self.client.patch(
            f"/api/v1/estudiantes/{original['id']}", json={"activo": True}
        )
        self.assertEqual(response.status_code, 400, response.text)

    def test_csv_and_xlsx_report_invalid_rows_without_creating_students(self):
        for xlsx in (False, True):
            with self.subTest(xlsx=xlsx):
                result = self.import_rows([
                    {"nombres": " "}, {"apellidos": ""},
                    {"fecha_nacimiento": ""}, {"fecha_nacimiento": "2006-01-01"},
                    {"fecha_nacimiento": "2018-11-05"},
                    {"fecha_nacimiento": "2016-11-04"},
                    {"fecha_nacimiento": "2026-11-05"},
                    {"fecha_nacimiento": "2018-02-30"},
                ], xlsx=xlsx)
                self.assertEqual(result["created_count"], 0)
                self.assertEqual(result["updated_count"], 0)
                self.assertEqual(result["error_count"], 8)
                self.assertTrue(
                    all(row["status"] == "error" for row in result["results"])
                )
                self.assertEqual(self.stored_students(), [])

    def test_import_only_creates_valid_rows_and_preserves_pin_on_update(self):
        result = self.import_rows([
            {"nombres": "  Estudiante  ", "apellidos": "  Prueba  "},
            {"nombres": "Otro", "fecha_nacimiento": "2006-01-01"},
        ])
        self.assertEqual(result["created_count"], 1)
        self.assertEqual(result["error_count"], 1)
        student = self.stored_students()[0]
        self.assertEqual(student.nombres, "Estudiante")
        self.assertEqual(student.apellidos, "Prueba")
        self.assertTrue(student.activo)
        self.assertRegex(student.pin_corto, r"^\d{4}$")
        result = self.import_rows([{
            "nombres": "Estudiante", "apellidos": "Prueba",
            "fecha_nacimiento": "2017-11-04",
        }])
        self.assertEqual(result["updated_count"], 1)
        updated = self.stored_students()[0]
        self.assertEqual(updated.pin_corto, student.pin_corto)
        self.assertEqual(updated.fecha_nacimiento, date(2017, 11, 4))

    def test_import_cannot_overwrite_a_valid_student_with_invalid_birth_date(self):
        original = self.create_student().json()
        result = self.import_rows([{"fecha_nacimiento": "2006-01-01"}])
        self.assertEqual(result["error_count"], 1)
        self.assertEqual(result["updated_count"], 0)
        student = self.stored_students()[0]
        self.assertEqual(student.pin_corto, original["pin_corto"])
        self.assertEqual(student.fecha_nacimiento.isoformat(), original["fecha_nacimiento"])


if __name__ == "__main__":
    unittest.main()
