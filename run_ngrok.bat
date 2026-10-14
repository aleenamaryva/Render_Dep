@echo off
title LifeTrace ngrok Tunnel
echo ====================================================
echo Connecting ngrok tunnel to local backend (port 8000)...
echo ====================================================

where ngrok >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: ngrok executable not found in PATH.
    pause
    exit /b 1
)

echo Static Domain: https://preliterate-shandi-celebratory.ngrok-free.dev
echo Exposing local port 8000...
echo ----------------------------------------------------

ngrok http --domain=preliterate-shandi-celebratory.ngrok-free.dev 8000
pause
