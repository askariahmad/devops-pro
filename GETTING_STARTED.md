# Developer Getting Started Guide: DevOps-Pro

Welcome to the **DevOps-Pro** project! This repository contains a microservices-based application integrated with an AI-driven security cache and deployed to an emulated Azure environment locally.

This guide provides a comprehensive, step-by-step walkthrough to set up your local development workspace from scratch.

---

## 1. Local Development Prerequisites

Before setting up the repository, make sure your host machine has the following tools installed:

| Tool | Recommended Version | Purpose |
| :--- | :--- | :--- |
| **Operating System** | Windows 10/11 (WSL2 enabled) | Host OS |
| **Docker Desktop** | Latest version (Kubernetes enabled) | Orchestrates containers and local cluster |
| **PowerShell Core** | v7.4+ (`pwsh`) | Execution environment for deployment scripts |
| **Java Development Kit** | JDK 21 | Backend compilation and execution |
| **Apache Maven** | v3.9+ | Backend project dependency builder |
| **Node.js & npm** | Node v20+, npm v9+ | Frontend compilation and package resolution |
| **Terraform** | v1.5+ | Infrastructure as Code (IaC) provisioning |

---

## 2. Setting Up Local Databases

The backend services depend on **MongoDB** and **Redis** caches. We run these databases as persistent Docker containers on the host machine to avoid cluster overhead.

Run the following commands in your terminal to start the databases:

```powershell
# 1. Start MongoDB (Document Store)
docker run -d -p 27017:27017 --name local-mongo mongo:latest

# 2. Start Redis (Distributed Cache)
docker run -d -p 6379:6379 --name local-redis redis:alpine
```

Verify that both containers are running by executing `docker ps`.

---

## 3. Working with Git Submodules

This project uses Git Submodules for all microservices and the React UI. When cloning the repository for the first time, you must pull all submodules recursively:

```powershell
# Clone parent repository
git clone https://github.com/askariahmad/devops-pro.git
cd devops-pro

# Initialize and clone all submodules recursively
git submodule update --init --recursive
```

### Submodule Modification Workflow:
Because microservices are separate Git repositories, any changes inside a service folder must be committed locally within that submodule before updating the parent repository references:

1. Make edits to files inside a service folder (e.g., `incident-service/src/...`).
2. Commit inside the submodules and update the parent pointer:
   ```powershell
   # Commit changes inside all submodules
   git submodule foreach "git commit -a -m 'feat: my changes' || true"
   
   # Stage and commit submodule pointers in the parent repository
   git add config-service dashboard-ui gateway-service incident-service log-analyzer-service log-collector-service notification-service repo-scanner-service
   git commit -m "chore: update submodule pointers"
   ```

---

## 4. Local Deployment via Terraform

Deploying the local infrastructure and launching the Kubernetes applications is managed by the `deploy.ps1` script.

To deploy locally using the **Floci-AZ** emulator:

```powershell
# Run the deployment script targeting local Azure emulation
pwsh ./deploy.ps1 -Cloud azure
```

### What this script does under the hood:
1. Verifies that a local Kubernetes cluster (Docker Desktop K8s, Minikube, or Kind) is active.
2. Compiles and packages all microservices and the React UI into Docker images.
3. Provisions the emulated Azure environment (`floci-az` container) on port `4577`.
4. Deploys the Kubernetes manifests using Terraform (`terraform/` folder), automatically routing database connections to `host.docker.internal` instead of `localhost`.

---

## 5. Setting Up Local Jenkins CI/CD

To automate your builds and monitor pod rollouts in real-time, configure a local Jenkins container:

### Step 1: Start the Jenkins Container
Start the official Jenkins LTS container, mounting your host's Docker socket and bind-mounting your project workspace directory as a volume (`/workspace`):

```powershell
docker run -d -p 9090:8080 -p 50000:50000 --name jenkins-local -u 0 -e JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home -v c:\Users\ahmad\IdeaProjects\devops-pro:/workspace jenkins/jenkins:lts-jdk21
```

### Step 2: Configure Git Protocols inside Jenkins
Newer Git client versions block local checkouts and submodule cloning over the file protocol. Run these commands on your host to authorize local checkouts inside the container:

```powershell
docker exec -u 0 jenkins-local git config --global protocol.file.allow always
docker exec -u jenkins jenkins-local git config --global protocol.file.allow always
docker exec -u 0 jenkins-local git config --global --add safe.directory '*'
docker exec -u jenkins jenkins-local git config --global --add safe.directory '*'
```

### Step 3: Seed Kubeconfig Credentials
To allow Jenkins to verify Kubernetes rollout status, copy your host's Kubeconfig credentials and route them through the host network bridge:

```powershell
# Create folder structure inside container
docker exec -u 0 jenkins-local mkdir -p /root/.kube /var/jenkins_home/.kube

# Copy host credentials
docker cp C:\Users\ahmad\.kube\config jenkins-local:/root/.kube/config
docker cp C:\Users\ahmad\.kube\config jenkins-local:/var/jenkins_home/.kube/config

# Patch localhost connections to use host.docker.internal and skip TLS check
docker exec -u 0 jenkins-local sed -i "s/127.0.0.1/host.docker.internal/g" /root/.kube/config
docker exec -u 0 jenkins-local sed -i "s/127.0.0.1/host.docker.internal/g" /var/jenkins_home/.kube/config
docker exec -u 0 jenkins-local sed -i "s/certificate-authority-data:.*$/insecure-skip-tls-verify: true/g" /root/.kube/config
docker exec -u 0 jenkins-local sed -i "s/certificate-authority-data:.*$/insecure-skip-tls-verify: true/g" /var/jenkins_home/.kube/config

# Reset permissions
docker exec -u 0 jenkins-local chown -R jenkins:jenkins /var/jenkins_home/.kube
```

### Step 4: Import and Run the Pipeline Job
Copy our pre-made job definition and restart Jenkins:

```powershell
docker exec -u 0 jenkins-local mkdir -p /var/jenkins_home/jobs/devops-pro-deploy
docker cp C:\Users\ahmad\.gemini\antigravity-ide\brain\bc0ab73c-2e29-4ae5-8533-43a91334ca05\scratch\config.xml jenkins-local:/var/jenkins_home/jobs/devops-pro-deploy/config.xml
docker exec -u 0 jenkins-local chown -R jenkins:jenkins /var/jenkins_home/jobs/devops-pro-deploy
docker restart jenkins-local
```

Once the container restarts, log into the Jenkins dashboard at `http://localhost:9090`, select the `devops-pro-deploy` job, and trigger **Build Now**!

---

## 6. Key Troubleshooting and Gotchas

- **PowerShell External Commands**: In PowerShell, native executables (like `docker build`) do not crash the script on failure. Always validate `$LASTEXITCODE` immediately after executing native binaries to prevent green-washing failed CI runs.
- **Dubious Submodule Ownership**: If Git operations fail with `dubious ownership`, ensure you run `git config --global --add safe.directory '*'` inside the container.
- **PowerShell Core Startup in Container**: If PowerShell Core (`pwsh`) crashes inside the Jenkins container, ensure the pipeline config includes `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true` to run PowerShell in globalization-invariant mode.
- **Maven compilation context**: Never use the `-am` (also make) flag in Dockerfile compiles if you only copy the src folder of a single module. Run `mvn clean package -pl <service> -DskipTests` to build the module in isolation.
