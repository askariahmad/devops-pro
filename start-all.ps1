$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Starting DevSecOps Platform" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Start Backing Infrastructure (Kafka, Zookeeper, Redis, Splunk)
Write-Host "`n[1/3] Starting Docker Infrastructure (Kafka, Redis, Zookeeper, Splunk)..." -ForegroundColor Yellow
docker-compose up -d

# Give Docker a few seconds to initialize
Start-Sleep -Seconds 5

# 2. Build the Windows Terminal (wt.exe) command
Write-Host "`n[2/3] Launching Microservices in Windows Terminal tabs..." -ForegroundColor Yellow

$basePath = (Get-Item .).FullName
$wtArgs = @()

# Config service starts immediately
$wtArgs += "new-tab --title `"config-service`" -d `"$basePath\config-service`" cmd /k `"mvn spring-boot:run`""

# Other services wait 10 seconds for config-service to boot
$services = "gateway-service", "incident-service", "repo-scanner-service", "log-analyzer-service", "log-collector-service", "notification-service"
foreach ($svc in $services) {
    $wtArgs += "new-tab --title `"$svc`" -d `"$basePath\$svc`" cmd /k `"timeout /t 10 >nul && mvn spring-boot:run`""
}

# 3. Add Dashboard UI tab
$wtArgs += "new-tab --title `"dashboard-ui`" -d `"$basePath\dashboard-ui`" cmd /k `"npm run dev`""

# Execute the command in the current Windows Terminal window (-w 0)
# The tabs are separated by a semicolon
$wtCmd = "wt -w 0 " + ($wtArgs -join " `; ")

try {
    Invoke-Expression $wtCmd
} catch {
    Write-Host "Failed to open tabs in current window. You must be running this from Windows Terminal." -ForegroundColor Red
    Write-Host "Attempting to open in a new Windows Terminal window instead..." -ForegroundColor Yellow
    $wtCmdFallback = "wt " + ($wtArgs -join " `; ")
    Invoke-Expression $wtCmdFallback
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " All services have been launched as tabs!" -ForegroundColor Green
Write-Host " - You can access the UI at: http://localhost:5173"
Write-Host "=========================================" -ForegroundColor Cyan
