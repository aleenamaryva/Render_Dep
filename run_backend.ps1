# LifeTrace Backend PowerShell Launcher
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Starting LifeTrace FastAPI Backend Server..." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$backendDir = Join-Path $PSScriptRoot "backend"
$uvicornPath = Join-Path $backendDir ".venv\Scripts\uvicorn.exe"

if (-not (Test-Path $uvicornPath)) {
    Write-Host "Error: Virtual environment .venv not found in backend directory." -ForegroundColor Red
    exit 1
}

Write-Host "Uvicorn running on: http://127.0.0.1:8000" -ForegroundColor Green
Write-Host "API Docs: http://127.0.0.1:8000/docs" -ForegroundColor Yellow
Write-Host "Dashboard: http://127.0.0.1:8000/dashboard/" -ForegroundColor Yellow
Write-Host "----------------------------------------------------"

Set-Location $backendDir
& $uvicornPath app.main:app --reload --host 127.0.0.1 --port 8000
