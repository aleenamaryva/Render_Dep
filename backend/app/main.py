from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select

from .config import get_settings
from .database import SessionLocal
from .models import User
from .security import hash_password
from .routers.auth import router as auth_router
from .routers.admin import router as admin_router
from .routers.responses import router as responses_router


def ensure_default_admin() -> None:
    try:
        with SessionLocal() as db:
            admin = db.scalar(select(User).where(User.email == "admin@lifetrace.com"))
            if not admin:
                default_admin = User(
                    full_name="LifeTrace Administrator",
                    email="admin@lifetrace.com",
                    password_hash=hash_password("admin123"),
                    phone_number="+919876543210",
                    emergency_contact_name="Control Room",
                    emergency_contact_phone="+919876543210",
                    blood_group="O+",
                    role="admin",
                )
                db.add(default_admin)
                db.commit()
            elif admin.role != "admin":
                admin.role = "admin"
                db.commit()
    except Exception as e:
        print(f"Warning: could not seed default admin: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_default_admin()
    yield


settings = get_settings()
app = FastAPI(title="LifeTrace API", version="0.1.0", lifespan=lifespan)
_cors_origins = settings.cors_origin_list
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if "*" in _cors_origins else _cors_origins,
    allow_credentials=False if "*" in _cors_origins else True,
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "ngrok-skip-browser-warning"],
)
app.include_router(auth_router)
app.include_router(responses_router)
app.include_router(admin_router)
app.mount(
    "/dashboard",
    StaticFiles(directory=Path(__file__).resolve().parents[1] / "admin", html=True),
    name="dashboard",
)


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {"status": "ok"}
