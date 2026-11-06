import os
import secrets
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import jwt
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine, select
from sqlmodel.pool import StaticPool

from app.api.admin_demo import router
from app.db.session import get_session
from app.models.user import Usuario
from app.services.jwt_service import (
    JwtDecodeError, create_access_token, decode_access_token, validate_jwt_configuration,
)


class JwtConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.secret = secrets.token_urlsafe(48)
        environment = patch.dict(os.environ, {
            "JWT_SECRET_KEY": self.secret, "JWT_ALGORITHM": "HS256",
            "ACCESS_TOKEN_EXPIRE_MINUTES": "480",
        })
        environment.start()
        self.addCleanup(environment.stop)

    def test_requires_the_exact_secret_variable_without_fallback(self):
        for value in ("", "short-test-value"):
            with self.subTest(configured=bool(value)), patch.dict(os.environ, {
                "JWT_SECRET_KEY": value, "JWT_SECRET": self.secret,
            }):
                with self.assertRaisesRegex(RuntimeError, "JWT_SECRET_KEY"):
                    validate_jwt_configuration()

    def test_rejects_invalid_expiry_and_unsupported_algorithms(self):
        for minutes in ("0", "-1", "invalid"):
            with self.subTest(minutes=minutes), patch.dict(os.environ, {"ACCESS_TOKEN_EXPIRE_MINUTES": minutes}):
                with self.assertRaises(RuntimeError):
                    validate_jwt_configuration()
        for algorithm in ("none", "RS256", "invalid"):
            with self.subTest(algorithm=algorithm), patch.dict(os.environ, {"JWT_ALGORITHM": algorithm}):
                with self.assertRaises(RuntimeError):
                    validate_jwt_configuration()

    def test_preserves_480_minute_sessions_and_validates_signature_and_claims(self):
        token = create_access_token(user_id=7, email="ficticio@edu.com", rol="maestro")
        claims = decode_access_token(token)
        self.assertEqual(claims["sub"], "7")
        self.assertEqual(claims["rol"], "MAESTRO")
        self.assertEqual(claims["exp"] - claims["iat"], 480 * 60)
        with patch.dict(os.environ, {"JWT_SECRET_KEY": secrets.token_urlsafe(48)}):
            with self.assertRaises(JwtDecodeError):
                decode_access_token(token)
        with self.assertRaises(JwtDecodeError):
            decode_access_token(jwt.encode({"sub": "7"}, self.secret, algorithm="HS256"))
        claims["exp"] = int((datetime.now(timezone.utc) - timedelta(days=1)).timestamp())
        with self.assertRaises(JwtDecodeError):
            decode_access_token(jwt.encode(claims, self.secret, algorithm="HS256"))

    def test_startup_rejects_missing_key_before_database_connection(self):
        from app.main import on_startup
        with patch.dict(os.environ, {"JWT_SECRET_KEY": ""}), patch("app.main.create_db_and_tables") as create_db:
            with self.assertRaises(RuntimeError):
                on_startup()
            create_db.assert_not_called()
        with patch("app.main.create_db_and_tables") as create_db:
            on_startup()
            create_db.assert_called_once()


class DemoSeedTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool,
        )
        SQLModel.metadata.create_all(self.engine)
        self.addCleanup(self.engine.dispose)

        def local_session():
            with Session(self.engine) as session:
                yield session

        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_session] = local_session
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def test_seed_disabled_by_default_even_on_empty_database(self):
        for value in ("", "false", "1"):
            with self.subTest(value=value), patch.dict(os.environ, {"ENABLE_DEMO_SEED": value}):
                self.assertEqual(self.client.post("/api/v1/admin/seed-demo").status_code, 404)
        with Session(self.engine) as session:
            self.assertEqual(session.exec(select(Usuario)).all(), [])

    def test_explicit_demo_enablement_keeps_authenticated_reseed_guard(self):
        with patch.dict(os.environ, {"ENABLE_DEMO_SEED": "true"}):
            self.assertEqual(self.client.post("/api/v1/admin/seed-demo").status_code, 200)
            self.assertEqual(self.client.post("/api/v1/admin/seed-demo").status_code, 401)
        with patch.dict(os.environ, {"ENABLE_DEMO_SEED": "false"}):
            self.assertEqual(self.client.post("/api/v1/admin/seed-demo").status_code, 404)


class SyncMigrationTests(unittest.TestCase):
    def test_postgresql_migration_preserves_rows_and_has_unique_index(self):
        from app.db import migrate_sync_sessions
        engine = MagicMock()
        engine.dialect.name = "postgresql"
        connection = engine.begin.return_value.__enter__.return_value
        with patch.object(migrate_sync_sessions, "engine", engine), patch.object(
            migrate_sync_sessions, "inspect"
        ) as inspector:
            inspector.return_value.has_table.return_value = True
            migrate_sync_sessions.main()
        statements = [str(call.args[0]) for call in connection.execute.call_args_list]
        self.assertEqual(len(statements), 3)
        self.assertTrue(any("CREATE UNIQUE INDEX IF NOT EXISTS" in sql for sql in statements))
        self.assertFalse(any("DELETE" in sql or "DROP" in sql for sql in statements))

    def test_new_database_is_explicitly_left_for_schema_creation(self):
        from app.db import migrate_sync_sessions
        engine = MagicMock()
        engine.dialect.name = "postgresql"
        with patch.object(migrate_sync_sessions, "engine", engine), patch.object(
            migrate_sync_sessions, "inspect"
        ) as inspector:
            inspector.return_value.has_table.return_value = False
            migrate_sync_sessions.main()
        engine.begin.return_value.__enter__.return_value.execute.assert_not_called()

    def test_startup_identifies_missing_migration(self):
        from sqlalchemy import text
        from app.db import session as database
        engine = create_engine("sqlite://")
        try:
            with engine.begin() as connection:
                connection.execute(text("CREATE TABLE evaluaciones (id INTEGER PRIMARY KEY)"))
            with patch.object(database, "engine", engine):
                with self.assertRaisesRegex(RuntimeError, "migración"):
                    database.create_db_and_tables()
        finally:
            engine.dispose()

    def test_startup_requires_unique_identity_even_when_columns_exist(self):
        from sqlalchemy import text
        from app.db import session as database
        engine = create_engine("sqlite://")
        try:
            with engine.begin() as connection:
                connection.execute(text(
                    "CREATE TABLE evaluaciones (id INTEGER PRIMARY KEY, "
                    "local_session_id VARCHAR(128), sync_payload_hash VARCHAR(64))"
                ))
            with patch.object(database, "engine", engine):
                with self.assertRaisesRegex(RuntimeError, "migración"):
                    database.create_db_and_tables()
                with engine.begin() as connection:
                    connection.execute(text(
                        "CREATE UNIQUE INDEX ix_evaluaciones_local_session_id "
                        "ON evaluaciones (local_session_id)"
                    ))
                database.create_db_and_tables()
        finally:
            engine.dispose()
