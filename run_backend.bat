@echo off
title LifeTrace Backend (FastAPI)
echo ====================================================
echo Starting LifeTrace FastAPI Backend Server...
echo ====================================================

cd /d "%~dp0backend"

if not exist ".venv\Scripts\uvicorn.exe" (
    echo Error: Virtual environment .venv not found in backend directory.
    echo Please ensure dependencies are installed.
    pause
    exit /b 1
)

echo Activating .venv and launching Uvicorn on http://127.0.0.1:8000...
echo Swagger Docs: http://127.0.0.1:8000/docs
echo Admin Dashboard: http://127.0.0.1:8000/dashboard/
echo Health Check: http://127.0.0.1:8000/health
echo ----------------------------------------------------

.\.venv\Scripts\uvicorn.exe app.main:app --reload --host 127.0.0.1 --port 8000
pause
