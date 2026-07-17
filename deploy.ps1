param (
    [ValidateSet("azure", "aws")]
    [string]$Cloud = "azure",
    
    [ValidateSet("All", "Verify", "Build", "Emulator", "Clean", "Terraform", "Monitor", "BuildService", "MonitorService")]
    [string]$Stage = "All",
    
    [string]$ServiceName = ""
)

$ErrorActionPreference = "Stop"

# Define global variables
$services = @("config-service", "gateway-service", "incident-service", "notification-service", "repo-scanner-service", "log-analyzer-service", "log-collector-service")
$allServices = $services + @("dashboard-ui")

# --- Functions ---

# Helper to log status
function Log-Info([string]$msg) {
    Write-Host "`n🚀 $msg" -ForegroundColor Cyan
}

function Log-Step([string]$msg) {
    Write-Host "👉 $msg" -ForegroundColor Yellow
}

function Log-Success([string]$msg) {
    Write-Host "✅ $msg" -ForegroundColor Green
}

function Log-Warning([string]$msg) {
    Write-Host "⚠️ Warning: $msg" -ForegroundColor Yellow
}

function Log-Error([string]$msg) {
    Write-Host "❌ Error: $msg" -ForegroundColor Red
}

# 1. System Readiness and Auto-Start
function Verify-System-Readiness {
    Log-Info "Checking system prerequisites..."
    
    # Check Docker
    Log-Step "Verifying Docker is running..."
    $dockerInfo = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        $msg = ($dockerInfo | Out-String).Trim()
        if ($msg -match 'virtualization|not detected|not supported|cannot connect to the docker daemon|is not running') {
            Log-Error "Docker Desktop is not running or virtualization is disabled in BIOS."
        } else {
            Log-Error "Docker is unavailable: $msg"
        }
        exit 1
    }
    
    # Check kubectl
    Log-Step "Verifying kubectl is installed..."
    $hasKubectl = $null -ne (Get-Command kubectl -ErrorAction SilentlyContinue)
    if (-not $hasKubectl) {
        Log-Error "'kubectl' CLI tool not found in PATH. Please install it."
        exit 1
    }
    
    # Check active cluster
    Log-Step "Checking Kubernetes cluster connectivity..."
    & kubectl cluster-info --request-timeout="3s" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Log-Success "Kubernetes cluster is reachable!"
        return $true
    }
    
    Log-Warning "No active Kubernetes cluster detected. Attempting auto-start..."
    
    # Try Minikube
    if (Get-Command minikube -ErrorAction SilentlyContinue) {
        Log-Step "Found minikube. Starting local cluster..."
        & minikube start
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    
    # Try k3d
    if (Get-Command k3d -ErrorAction SilentlyContinue) {
        Log-Step "Found k3d. Starting/creating 'devops-pro' cluster..."
        $k3dClusters = & k3d cluster list -o json 2>$null | ConvertFrom-Json
        $hasCluster = $false
        if ($k3dClusters) {
            foreach ($c in $k3dClusters) {
                if ($c.name -eq "devops-pro") { $hasCluster = $true; break }
            }
        }
        if ($hasCluster) {
            & k3d cluster start devops-pro
        } else {
            & k3d cluster create devops-pro --port "80:80@loadbalancer" --port "443:443@loadbalancer"
        }
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    
    # Try Kind
    if (Get-Command kind -ErrorAction SilentlyContinue) {
        Log-Step "Found kind. Creating 'devops-pro' cluster..."
        & kind create cluster --name devops-pro
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    
    Log-Error "No active Kubernetes cluster, and failed to auto-provision one. Please enable Kubernetes in Docker Desktop."
    exit 1
}

# 2. Build Services
function Build-Docker-Images {
    Log-Info "Building and tagging microservice Docker images locally..."
    foreach ($service in $services) {
        Log-Step "Building ${service}..."
        docker build -t "devopsproprodacr.azurecr.io/${service}:latest" -f "${service}/Dockerfile" .
    }
    Log-Step "Building dashboard-ui..."
    docker build -t "devopsproprodacr.azurecr.io/dashboard-ui:latest" -f "dashboard-ui/Dockerfile" ./dashboard-ui
    Log-Success "All Docker images built successfully!"
}

# 3. Emulator setup
function Start-Emulator {
    Log-Info "Starting Floci emulator for $Cloud..."
    if ($Cloud -eq "azure") {
        $existingNetwork = & docker network ls --filter name=floci-network -q
        if (-not $existingNetwork) {
            & docker network create floci-network 2>$null | Out-Null
        }
        docker rm -f floci-az 2>$null | Out-Null
        docker run -d -p 4577:4577 -u 0 -e FLOCI_AZ_TLS_ENABLED=true -e FLOCI_AZ_SERVICES_AKS_MOCKED=true -v /var/run/docker.sock:/var/run/docker.sock --network floci-network --name floci-az floci/floci-az:latest | Out-Null
        
        Log-Step "Waiting for Floci-AZ to initialize on port 4577..."
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $client = [System.Net.Sockets.TcpClient]::new()
                $client.Connect("127.0.0.1", 4577)
                $client.Dispose()
                $ready = $true
                break
            } catch {
                Start-Sleep -Seconds 1
            }
        }
        if (-not $ready) {
            Log-Error "Floci-AZ emulator did not become reachable."
            exit 1
        }
        
        # Configure certificate
        Log-Step "Downloading TLS certificate from Floci..."
        $certPath = Join-Path $PSScriptRoot "floci-az.pem"
        $certDownloaded = $false
        for ($j = 0; $j -lt 15; $j++) {
            try {
                Invoke-WebRequest -Uri "http://localhost:4577/_floci/tls-cert" -OutFile $certPath -UseBasicParsing -TimeoutSec 2
                $certDownloaded = $true
                break
            } catch {
                Start-Sleep -Seconds 2
            }
        }
        if ($certDownloaded) {
            Log-Step "Importing TLS certificate to Trusted Root store silently..."
            certutil -user -addstore -f root $certPath | Out-Null
            Log-Success "TLS Certificate configured successfully!"
        } else {
            Log-Warning "Failed to download TLS certificate. Emulator may have SSL validation issues."
        }
    } else {
        docker rm -f floci-aws 2>$null | Out-Null
        docker run -d -p 4566:4566 --name floci-aws floci/floci:latest | Out-Null
        
        Log-Step "Waiting for Floci-AWS to initialize on port 4566..."
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $client = [System.Net.Sockets.TcpClient]::new()
                $client.Connect("127.0.0.1", 4566)
                $client.Dispose()
                $ready = $true
                break
            } catch {
                Start-Sleep -Seconds 1
            }
        }
        if (-not $ready) {
            Log-Error "Floci-AWS emulator did not become reachable."
            exit 1
        }
        Log-Success "Floci-AWS is ready!"
    }
}

# 4. Fingerprint Calculation
function Get-Service-Triggers {
    Log-Info "Calculating file-modified triggers for incremental deploys..."
    $triggers = @{}
    foreach ($service in $allServices) {
        $servicePath = Join-Path $PSScriptRoot $service
        if (Test-Path $servicePath) {
            $files = Get-ChildItem -Path $servicePath -Recurse -File
            if ($files) {
                $maxWrite = ($files | Measure-Object -Property LastWriteTime -Maximum).Maximum.Ticks
                $triggers[$service] = $maxWrite.ToString()
            } else {
                $triggers[$service] = "0"
            }
        } else {
            $triggers[$service] = "0"
        }
    }
    $triggersJson = $triggers | ConvertTo-Json -Compress
    Log-Success "Trigger calculations complete."
    return $triggersJson
}

# 5. Conflict Resolution Cleanup
function Clean-Untracked-Deployments {
    Log-Info "Reading Terraform state to check for conflicting untracked resources..."
    $stateList = @()
    $statePath = Join-Path (Join-Path $PSScriptRoot "terraform") "terraform.tfstate"
    if (Test-Path $statePath) {
        try {
            $stateContent = Get-Content $statePath -Raw
            if ($stateContent) {
                $stateJson = ConvertFrom-Json $stateContent
                if ($stateJson -and $stateJson.resources) {
                    foreach ($res in $stateJson.resources) {
                        if ($res.type -eq "kubernetes_deployment_v1" -and $res.name -eq "services" -and $res.index) {
                            $stateList += "kubernetes_deployment_v1.services[`"$($res.index)`"]"
                        }
                    }
                }
            }
        } catch {
            Log-Warning "Could not parse terraform.tfstate: $_"
        }
    }
    
    $deploymentsToDelete = @()
    foreach ($service in $allServices) {
        $deploymentKey = "kubernetes_deployment_v1.services[`"$service`"]"
        if ($stateList -notcontains $deploymentKey) {
            $deploymentsToDelete += $service
        }
    }
    
    if ($deploymentsToDelete.Count -gt 0) {
        $names = [string]::Join(",", $deploymentsToDelete)
        Log-Warning "Conflicting untracked deployments found in cluster. Force-deleting: $names"
        
        $oldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & kubectl delete deployment $names --ignore-not-found --grace-period=0 --force --request-timeout="5s" 2>$null | Out-Null
        } finally {
            $ErrorActionPreference = $oldEap
        }
        
        Log-Success "Conflicting deployments cleared."
    } else {
        Log-Success "No conflicting untracked deployments found."
    }
}

# 6. Monitor Rollout progress
function Monitor-Rollout {
    Log-Info "Monitoring Kubernetes Pods rollout in real-time..."
    foreach ($service in $allServices) {
        Write-Host "`n--- Monitoring: $service ---" -ForegroundColor Cyan
        $podReady = $false
        
        for ($i = 0; $i -lt 30; $i++) {
            $pods = & kubectl get pods -l app=$service -o json 2>$null | ConvertFrom-Json
            if ($pods -and $pods.items -and $pods.items.Count -gt 0) {
                $pod = $pods.items[0]
                $podName = $pod.metadata.name
                $phase = $pod.status.phase
                $containerStatuses = $pod.status.containerStatuses
                
                if ($containerStatuses -and $containerStatuses.Count -gt 0) {
                    $cStatus = $containerStatuses[0]
                    $ready = $cStatus.ready
                    
                    Write-Host "   Pod: $podName | Phase: $phase | Ready: $ready" -ForegroundColor DarkGray
                    
                    if ($ready -eq $true -or $ready -eq "True") {
                        Log-Success "$service is running and ready!"
                        $podReady = $true
                        break
                    }
                    
                    if ($cStatus.state.waiting) {
                        $reason = $cStatus.state.waiting.reason
                        $message = $cStatus.state.waiting.message
                        Write-Host "   ⚠️ Status: Waiting ($reason) - $message" -ForegroundColor Yellow
                        
                        if ($reason -match "ImagePullBackOff|ErrImagePull|CrashLoopBackOff|RunContainerError") {
                            Log-Error "Pod stuck in waiting state ($reason). Fetching event logs..."
                            & kubectl describe pod $podName 2>$null | Select-String -Pattern "Events:" -Context 0, 10
                            Write-Host "   Latest container logs:" -ForegroundColor DarkGray
                            & kubectl logs $podName --tail=15 2>$null
                            break
                        }
                    }
                    
                    if ($cStatus.state.terminated) {
                        Log-Error "Container terminated: $($cStatus.state.terminated.reason)"
                        & kubectl logs $podName --tail=15 2>$null
                        break
                    }
                } else {
                    Write-Host "   Pod scheduled but container status pending..." -ForegroundColor DarkGray
                }
            } else {
                Write-Host "   Waiting for pod scheduling..." -ForegroundColor DarkGray
            }
            Start-Sleep -Seconds 2
        }
        
        if (-not $podReady) {
            Log-Warning "$service did not become ready in 60 seconds. Skipping diagnostics."
        }
    }
}

# --- Execution ---

if ($Stage -eq "Verify") {
    Verify-System-Readiness
}
elseif ($Stage -eq "Build") {
    Build-Docker-Images
}
elseif ($Stage -eq "BuildService") {
    if ($ServiceName -eq "dashboard-ui") {
        Log-Info "Building UI image: dashboard-ui..."
        npm ci --prefix dashboard-ui
        npm run build --prefix dashboard-ui
        & docker build -t devopsproprodacr.azurecr.io/dashboard-ui:latest -f dashboard-ui/Dockerfile dashboard-ui/
    } else {
        Log-Info "Building service image: $ServiceName..."
        & docker build -t "devopsproprodacr.azurecr.io/${ServiceName}:latest" -f "${ServiceName}/Dockerfile" .
    }
}
elseif ($Stage -eq "Emulator") {
    Start-Emulator
}
elseif ($Stage -eq "Clean") {
    Clean-Untracked-Deployments
}
elseif ($Stage -eq "Terraform") {
    $triggersJson = Get-Service-Triggers
    Push-Location (Join-Path $PSScriptRoot "terraform")
    try {
        $env:TF_VAR_service_triggers = $triggersJson
        Log-Info "Executing Terraform IaC..."
        Log-Step "Initializing Terraform..."
        terraform init
        Log-Step "Applying plan (Auto-Approve)..."
        terraform apply -auto-approve -var='create_azure_infra=true' -var='azure_metadata_host=localhost:4577' -var='create_cosmos_and_keyvault=false'
        Log-Success "Terraform applied successfully!"
    }
    finally {
        Remove-Item Env:\TF_VAR_service_triggers -ErrorAction SilentlyContinue
        Pop-Location
    }
}
elseif ($Stage -eq "Monitor") {
    Monitor-Rollout
}
elseif ($Stage -eq "MonitorService") {
    Log-Info "Monitoring Kubernetes Pod rollout for $ServiceName..."
    $podReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        $pods = & kubectl get pods -l app=$ServiceName -o json 2>$null | ConvertFrom-Json
        if ($pods -and $pods.items -and $pods.items.Count -gt 0) {
            $pod = $pods.items[0]
            $podName = $pod.metadata.name
            $phase = $pod.status.phase
            $containerStatuses = $pod.status.containerStatuses
            
            if ($containerStatuses -and $containerStatuses.Count -gt 0) {
                $cStatus = $containerStatuses[0]
                $ready = $cStatus.ready
                
                Write-Host "   Pod: $podName | Phase: $phase | Ready: $ready" -ForegroundColor DarkGray
                
                if ($ready -eq $true -or $ready -eq "True") {
                    Log-Success "$ServiceName is running and ready!"
                    $podReady = $true
                    break
                }
                
                if ($cStatus.state.waiting) {
                    $reason = $cStatus.state.waiting.reason
                    $message = $cStatus.state.waiting.message
                    Write-Host "   ⚠️ Status: Waiting ($reason) - $message" -ForegroundColor Yellow
                    
                    if ($reason -match "ImagePullBackOff|ErrImagePull|CrashLoopBackOff|RunContainerError") {
                        Log-Error "Pod stuck in waiting state ($reason). Fetching event logs..."
                        & kubectl describe pod $podName 2>$null | Select-String -Pattern "Events:" -Context 0, 10
                        Write-Host "   Latest container logs:" -ForegroundColor DarkGray
                        & kubectl logs $podName --tail=15 2>$null
                        exit 1
                    }
                }
                
                if ($cStatus.state.terminated) {
                    Log-Error "Container terminated: $($cStatus.state.terminated.reason)"
                    & kubectl logs $podName --tail=15 2>$null
                    exit 1
                }
            } else {
                Write-Host "   Pod scheduled but container status pending..." -ForegroundColor DarkGray
            }
        } else {
            Write-Host "   Waiting for pod scheduling..." -ForegroundColor DarkGray
        }
        Start-Sleep -Seconds 2
    }
    
    if (-not $podReady) {
        Log-Error "$ServiceName did not become ready in 60 seconds."
        exit 1
    }
}
else {
    Verify-System-Readiness
    Build-Docker-Images
    Start-Emulator
    
    $triggersJson = Get-Service-Triggers
    Push-Location (Join-Path $PSScriptRoot "terraform")
    try {
        Clean-Untracked-Deployments
        $env:TF_VAR_service_triggers = $triggersJson
        Log-Info "Executing Terraform IaC..."
        Log-Step "Initializing Terraform..."
        terraform init
        Log-Step "Applying plan (Auto-Approve)..."
        terraform apply -auto-approve -var='create_azure_infra=true' -var='azure_metadata_host=localhost:4577' -var='create_cosmos_and_keyvault=false'
        Log-Success "Terraform applied successfully!"
    }
    finally {
        Remove-Item Env:\TF_VAR_service_triggers -ErrorAction SilentlyContinue
        Pop-Location
    }
    Monitor-Rollout
    Log-Success "Deployment Automation completed successfully!"
}
