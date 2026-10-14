# LifeTrace ngrok PowerShell Launcher
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Connecting ngrok tunnel to local backend (port 8000)..." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
if (-not $ngrokCmd) {
    Write-Host "Error: ngrok is not found in PATH." -ForegroundColor Red
    exit 1
}

Write-Host "Static Domain: https://preliterate-shandi-celebratory.ngrok-free.dev" -ForegroundColor Green
Write-Host "Exposing local port 8000..." -ForegroundColor Yellow
Write-Host "----------------------------------------------------"

ngrok http --domain=preliterate-shandi-celebratory.ngrok-free.dev 8000
