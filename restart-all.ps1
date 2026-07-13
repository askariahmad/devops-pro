$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Restarting DevSecOps Platform" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "`n>>> Triggering Stop Script..." -ForegroundColor Yellow
PowerShell -ExecutionPolicy Bypass -File .\stop-all.ps1

Write-Host "`nWaiting 3 seconds before starting up..." -ForegroundColor DarkGray
Start-Sleep -Seconds 3

Write-Host "`n>>> Triggering Start Script..." -ForegroundColor Yellow
PowerShell -ExecutionPolicy Bypass -File .\start-all.ps1
