param (
    [ValidateSet("azure", "aws")]
    [string]$Cloud = "azure"
)

Write-Host "🚀 Starting Deployment Automation for $Cloud..." -ForegroundColor Cyan

# 1. Start External Services
Write-Host "`n[1/2] (No external services needed. Redis is now natively managed!)" -ForegroundColor DarkGray

# 2. Start Floci Emulator
Write-Host "`n[2/2] Starting Floci Emulator for $Cloud..." -ForegroundColor Yellow
if ($Cloud -eq "azure") {
    docker rm -f floci-az 2>$null
    docker run -d -p 4577:4577 --name floci-az floci/floci-az:latest
} else {
    docker rm -f floci-aws 2>$null
    docker run -d -p 4566:4566 --name floci-aws floci/floci:latest
}

# Wait for emulator to be fully ready
Write-Host "Waiting 5 seconds for Floci to initialize..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5

# 3. Run Terraform
Write-Host "`n[3/3] Executing Terraform IaC..." -ForegroundColor Yellow
if (Test-Path "terraform") {
    Push-Location terraform
    
    Write-Host "Initializing Terraform..."
    terraform init
    
    Write-Host "Applying Terraform (Auto-Approve)..."
    terraform apply -auto-approve
    
    Pop-Location
    Write-Host "`n✅ Deployment Complete! The full application is now running natively inside Floci." -ForegroundColor Green
} else {
    Write-Host "`n❌ Error: 'terraform' directory not found. Please ensure you are on the correct branch (feat/azure-migration or feat/aws-migration)." -ForegroundColor Red
}
