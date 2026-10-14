@echo off
title LifeTrace Flutter App
echo ====================================================
echo Launching LifeTrace Flutter App...
echo ====================================================

cd /d "%~dp0"

where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Error: flutter executable not found in PATH.
    pause
    exit /b 1
)

if exist "C:\Program Files\Android\Android Studio\jbr" (
    set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
)

echo API Target: https://preliterate-shandi-celebratory.ngrok-free.dev
echo Starting flutter run...
echo ----------------------------------------------------

flutter run --dart-define=API_BASE_URL=https://preliterate-shandi-celebratory.ngrok-free.dev
pause
