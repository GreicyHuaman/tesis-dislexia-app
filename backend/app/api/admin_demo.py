from fastapi import APIRouter, Depends
from sqlmodel import Session, select

from app.db.session import get_session
from app.models.section import DocenteSeccion, Seccion
from app.models.user import Usuario
from app.services.password_service import hash_password

router = APIRouter(
    prefix="/api/v1/admin",
    tags=["admin"],
)


@router.post("/seed-demo")
def seed_demo_data(
    session: Session = Depends(get_session),
):
    secciones_demo = [
        {
            "grado": 3,
            "nombre": "3A",
            "turno": "MAÑANA",
        },
        {
            "grado": 3,
            "nombre": "3B",
            "turno": "MAÑANA",
        },
    ]

    created_sections = []

    for item in secciones_demo:
        existing = session.exec(
            select(Seccion).where(
                Seccion.grado == item["grado"],
                Seccion.nombre == item["nombre"],
            )
        ).first()

        if existing is None:
            seccion = Seccion(**item)
            session.add(seccion)
            session.commit()
            session.refresh(seccion)
            created_sections.append(seccion)
        else:
            created_sections.append(existing)

    users_demo = [
        {
            "nombres": "María",
            "apellidos": "Docente 3A",
            "email": "maestra3a@demo.com",
            "rol": "MAESTRO",
            "password": "123456",
            "grado_scope": None,
        },
        {
            "nombres": "Rosa",
            "apellidos": "Psicóloga",
            "email": "psicologa@demo.com",
            "rol": "PSICOLOGA",
            "password": "123456",
            "grado_scope": 3,
        },
        {
            "nombres": "Elena",
            "apellidos": "Directora",
            "email": "directora@demo.com",
            "rol": "DIRECTORA",
            "password": "123456",
            "grado_scope": 3,
        },
    ]

    created_users = []

    for item in users_demo:
        email = item["email"].strip().lower()

        existing_user = session.exec(
            select(Usuario).where(
                Usuario.email == email,
            )
        ).first()

        if existing_user is None:
            usuario = Usuario(
                nombres=item["nombres"],
                apellidos=item["apellidos"],
                email=email,
                rol=item["rol"],
                password_hash=hash_password(item["password"]),
                grado_scope=item["grado_scope"],
                activo=True,
            )
            session.add(usuario)
            session.commit()
            session.refresh(usuario)
            created_users.append(usuario)
        else:
            created_users.append(existing_user)

    maestra = next(
        usuario for usuario in created_users if usuario.rol == "MAESTRO"
    )

    seccion_3a = next(
        seccion for seccion in created_sections if seccion.nombre == "3A"
    )

    existing_link = session.exec(
        select(DocenteSeccion).where(
            DocenteSeccion.usuario_id == maestra.id,
            DocenteSeccion.seccion_id == seccion_3a.id,
        )
    ).first()

    if existing_link is None:
        link = DocenteSeccion(
            usuario_id=maestra.id or 0,
            seccion_id=seccion_3a.id or 0,
        )
        session.add(link)
        session.commit()

    return {
        "status": "ok",
        "message": "Datos demo creados o ya existentes.",
        "usuarios": [
            {
                "id": usuario.id,
                "email": usuario.email,
                "rol": usuario.rol,
                "password_demo": "123456",
                "grado_scope": usuario.grado_scope,
            }
            for usuario in created_users
        ],
        "secciones": [
            {
                "id": seccion.id,
                "grado": seccion.grado,
                "nombre": seccion.nombre,
                "turno": seccion.turno,
            }
            for seccion in created_sections
        ],
    }
