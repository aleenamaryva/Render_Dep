# LifeTrace Flutter App PowerShell Launcher
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Launching LifeTrace Flutter App..." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Host "Error: flutter is not found in PATH." -ForegroundColor Red
    exit 1
}

if (Test-Path "C:\Program Files\Android\Android Studio\jbr") {
    $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
}

$apiUrl = "https://preliterate-shandi-celebratory.ngrok-free.dev"
Write-Host "Backend API URL: $apiUrl" -ForegroundColor Green
Write-Host "Running: flutter run --dart-define=API_BASE_URL=$apiUrl" -ForegroundColor Yellow
Write-Host "----------------------------------------------------"

Set-Location $PSScriptRoot
flutter run "--dart-define=API_BASE_URL=$apiUrl"
