# DevOps Pro Setup Guide

This guide covers the complete setup process for the DevOps Pro microservices architecture, including running it locally and pushing it to GitHub with each microservice as a Git submodule.

## Prerequisites
- Java 21+
- Maven 3.8+
- Node.js 18+ & npm
- MongoDB (running locally on port `27017`)
- Git

---

## 1. Local Database Setup
1. Ensure your MongoDB instance is running locally on the default port `27017`.
2. The `gateway-service` (Authentication) and `config-service` (System Settings) will automatically connect and create their logical databases (`devops-pro-auth` and `devops-pro-config`).
3. **Test Users:** Upon first boot, the `gateway-service` automatically seeds two mock users into the database:
   - **Username:** `admin`, **Password:** `admin123`
   - **Username:** `user1`, **Password:** `password`

## 2. Running the Microservices
Navigate to the root directory and start the services in the following order:

### Backend Services
```bash
# 1. Config Service (Port 8082)
cd config-service
mvn spring-boot:run

# 2. Gateway & Auth Service (Port 8080)
cd gateway-service
mvn spring-boot:run

# 3. Log Analyzer Service (Port 8081)
cd log-analyzer-service
mvn spring-boot:run

# 4. Log Collector Service (Port 8083)
cd log-collector-service
mvn spring-boot:run

# 5. Incident Service (Port 8084)
cd incident-service
mvn spring-boot:run

# 6. Repo Scanner Service (Port 8085)
cd repo-scanner-service
mvn spring-boot:run
```

### Frontend Application
```bash
# Dashboard UI (Port 5173 - Vite)
cd dashboard-ui
npm install
npm run dev
```

## 3. GitHub Submodule Architecture

To push the entire monorepo to GitHub where each microservice acts as an independent Git Submodule (Sub Repository), follow these steps:

### Step A: Create the Repositories on GitHub
You will need to create 8 empty repositories in your GitHub account:
1. `devops-pro-main` (The root monorepo)
2. `devops-pro-gateway`
3. `devops-pro-config`
4. `devops-pro-analyzer`
5. `devops-pro-collector`
6. `devops-pro-incident`
7. `devops-pro-scanner`
8. `devops-pro-ui`

### Step B: Initialize and Push Sub-repositories
Run the following commands for **each** microservice directory. (Example shown for `gateway-service`):

```bash
cd gateway-service
git init
git add .
git commit -m "Initial commit for gateway-service"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/devops-pro-gateway.git
git push -u origin main
cd ..
```
*(Repeat this for `config-service`, `log-analyzer-service`, `log-collector-service`, `incident-service`, `repo-scanner-service`, and `dashboard-ui`)*

### Step C: Initialize the Root Monorepo
Once all sub-repositories are pushed to GitHub, initialize the root directory and link them as submodules:

```bash
# In the root directory (devops-pro)
git init
git add pom.xml SETUP.md

# Add each microservice as a submodule
git submodule add https://github.com/YOUR_USERNAME/devops-pro-gateway.git gateway-service
git submodule add https://github.com/YOUR_USERNAME/devops-pro-config.git config-service
git submodule add https://github.com/YOUR_USERNAME/devops-pro-analyzer.git log-analyzer-service
git submodule add https://github.com/YOUR_USERNAME/devops-pro-collector.git log-collector-service
git submodule add https://github.com/YOUR_USERNAME/devops-pro-incident.git incident-service
git submodule add https://github.com/YOUR_USERNAME/devops-pro-scanner.git repo-scanner-service
git submodule add https://github.com/YOUR_USERNAME/devops-pro-ui.git dashboard-ui

# Commit and push the root monorepo
git commit -m "Initial commit for DevOps Pro Monorepo with submodules"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/devops-pro-main.git
git push -u origin main
```

## 4. First Login & Onboarding
1. Open your browser to `http://localhost:5173`.
2. Click **Mock Sign In** using the credentials: `admin` / `admin123`.
3. You will be redirected to the **Onboarding Screen**.
4. Configure your Splunk, Jira, and GitHub credentials. Use the **Test Connection** buttons to verify connectivity.
5. Click **Complete Onboarding** to unlock the main Dashboard and Repository overview!
