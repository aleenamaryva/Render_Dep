from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import get_settings
from .routers.auth import router as auth_router
from .routers.admin import router as admin_router
from .routers.responses import router as responses_router

settings = get_settings()
app = FastAPI(title="LifeTrace API", version="0.1.0")
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
