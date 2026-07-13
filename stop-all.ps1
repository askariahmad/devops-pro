$ErrorActionPreference = "Continue"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Stopping DevSecOps Platform" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Terminating Spring Boot Microservices..." -ForegroundColor Yellow
$javaProcesses = Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -match "spring-boot" }
if ($javaProcesses) {
    foreach ($proc in $javaProcesses) {
        Write-Host " -> Killing Java process (PID: $($proc.ProcessId))" -ForegroundColor DarkGray
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host " -> No running Spring Boot services found." -ForegroundColor DarkGray
}

Write-Host "`n[2/3] Terminating Dashboard UI (Vite/Node)..." -ForegroundColor Yellow
$nodeProcesses = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match "vite" }
if ($nodeProcesses) {
    foreach ($proc in $nodeProcesses) {
        Write-Host " -> Killing Node process (PID: $($proc.ProcessId))" -ForegroundColor DarkGray
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host " -> No running Dashboard UI found." -ForegroundColor DarkGray
}

Write-Host "`n[3/3] Stopping Docker Infrastructure (Kafka, Redis, Zookeeper)..." -ForegroundColor Yellow
docker-compose down

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host " All services have been stopped successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
