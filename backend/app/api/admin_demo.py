from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.db.session import get_session
from app.models.section import DocenteSeccion, Seccion
from app.models.user import Usuario
from app.services.password_service import hash_password

router = APIRouter(
    prefix="/api/v1/admin",
    tags=["admin-demo"],
)


def _get_or_create_section(
    session: Session,
    grado: int,
    nombre: str,
    turno: str,
) -> Seccion:
    section = session.exec(
        select(Seccion).where(
            Seccion.grado == grado,
            Seccion.nombre == nombre,
        )
    ).first()

    if section is not None:
        section.turno = turno
        section.activo = True
        session.add(section)
        session.commit()
        session.refresh(section)
        return section

    section = Seccion(
        grado=grado,
        nombre=nombre,
        turno=turno,
        activo=True,
    )

    session.add(section)
    session.commit()
    session.refresh(section)

    return section


def _upsert_user(
    session: Session,
    *,
    nombres: str,
    apellidos: str,
    email: str,
    rol: str,
    grado_scope: int | None,
    password: str,
) -> Usuario:
    normalized_email = email.strip().lower()

    user = session.exec(
        select(Usuario).where(
            Usuario.email == normalized_email,
        )
    ).first()

    if user is None:
        user = Usuario(
            nombres=nombres,
            apellidos=apellidos,
            email=normalized_email,
            rol=rol,
            password_hash=hash_password(password),
            grado_scope=grado_scope,
            activo=True,
        )
    else:
        user.nombres = nombres
        user.apellidos = apellidos
        user.email = normalized_email
        user.rol = rol
        user.password_hash = hash_password(password)
        user.grado_scope = grado_scope
        user.activo = True

    session.add(user)
    session.commit()
    session.refresh(user)

    return user


def _ensure_teacher_section_link(
    session: Session,
    usuario_id: int,
    seccion_id: int,
) -> None:
    existing = session.exec(
        select(DocenteSeccion).where(
            DocenteSeccion.usuario_id == usuario_id,
            DocenteSeccion.seccion_id == seccion_id,
        )
    ).first()

    if existing is not None:
        return

    link = DocenteSeccion(
        usuario_id=usuario_id,
        seccion_id=seccion_id,
    )

    session.add(link)
    session.commit()


@router.post("/seed-demo")
def seed_demo_data(
    session: Session = Depends(get_session),
):
    section_3a = _get_or_create_section(
        session=session,
        grado=3,
        nombre="A",
        turno="MAÑANA",
    )

    section_3b = _get_or_create_section(
        session=session,
        grado=3,
        nombre="B",
        turno="MAÑANA",
    )

    teacher = _upsert_user(
        session=session,
        nombres="María",
        apellidos="Docente Demo",
        email="maestra3a@demo.com",
        rol="MAESTRO",
        grado_scope=None,
        password="123456",
    )

    psychologist = _upsert_user(
        session=session,
        nombres="Lucía",
        apellidos="Psicóloga Demo",
        email="psicologa@demo.com",
        rol="PSICOLOGA",
        grado_scope=3,
        password="123456",
    )

    director = _upsert_user(
        session=session,
        nombres="Rosa",
        apellidos="Directora Demo",
        email="directora@demo.com",
        rol="DIRECTORA",
        grado_scope=3,
        password="123456",
    )

    if teacher.id is not None and section_3a.id is not None:
        _ensure_teacher_section_link(
            session=session,
            usuario_id=teacher.id,
            seccion_id=section_3a.id,
        )

    return {
        "status": "ok",
        "message": "Datos demo creados o actualizados.",
        "credentials": [
            {
                "email": teacher.email,
                "password": "123456",
                "rol": teacher.rol,
                "seccion_id": section_3a.id,
            },
            {
                "email": psychologist.email,
                "password": "123456",
                "rol": psychologist.rol,
                "grado_scope": psychologist.grado_scope,
            },
            {
                "email": director.email,
                "password": "123456",
                "rol": director.rol,
                "grado_scope": director.grado_scope,
            },
        ],
        "sections": [
            {
                "id": section_3a.id,
                "grado": section_3a.grado,
                "nombre": section_3a.nombre,
            },
            {
                "id": section_3b.id,
                "grado": section_3b.grado,
                "nombre": section_3b.nombre,
            },
        ],
    }
