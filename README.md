# DevOps Pro

**DevOps Pro** is an advanced, microservices-based platform designed to automate, monitor, and analyze CI/CD pipelines, system logs, and GitHub repositories. It integrates directly with industry-standard tools like Splunk, Jira, and GitHub, and leverages LangChain4j and AI models to automatically detect anomalies and generate actionable incident reports.

---

## Architecture Overview

DevOps Pro is built using a highly scalable, event-driven microservices architecture:

- **Frontend (`dashboard-ui`)**: A modern React application built with Vite. It features a minimalist, Vercel-inspired UI with dark mode support, Microsoft Entra ID (MSAL) authentication, and an intuitive onboarding flow for external configurations.
- **API Gateway (`gateway-service`)**: Built with Spring Cloud Gateway and Spring WebFlux. It handles cross-origin requests, JWT authentication (local + Entra ID), and routing traffic to internal services.
- **Config Service (`config-service`)**: Centralized configuration management. Stores tenant-specific settings (Splunk URLs, Jira tokens, LLM API keys) in MongoDB.
- **Log Collector Service (`log-collector-service`)**: Polls and collects logs from external sources like Splunk based on configured intervals.
- **Log Analyzer Service (`log-analyzer-service`)**: Leverages LangChain4j and configured LLMs to semantically analyze collected logs for anomalies or critical errors.
- **Incident Service (`incident-service`)**: Generates and manages incidents. It can automatically create Jira tickets when the analyzer flags a critical issue.
- **Repo Scanner Service (`repo-scanner-service`)**: Integrates with GitHub to scan linked repositories for dependency vulnerabilities and code quality metrics.
- **Database**: Each microservice is configured to use its own logical MongoDB database (e.g., `devops-pro-auth`, `devops-pro-config`), adhering to the "Database per Microservice" pattern for loose coupling.

---

## Complete Setup Guide

Follow these instructions to run DevOps Pro locally and push the architecture to GitHub as sub-repositories (Git submodules).

### Prerequisites
- **Java 21+**
- **Maven 3.8+**
- **Node.js 18+** & npm
- **MongoDB** (running locally on port `27017`)
- **Git**

### 1. Local Database Setup
1. Ensure your MongoDB instance is running locally on the default port `27017`.
2. The `gateway-service` and `config-service` will automatically connect and create their respective logical databases on startup.
3. **Test Users:** Upon first boot, the `gateway-service` automatically seeds two mock users into the database for local testing:
   - **Username:** `admin`, **Password:** `admin123`
   - **Username:** `user1`, **Password:** `password`

### 2. Running the Microservices
Navigate to the root directory and start the services in the following order (opening a new terminal for each):

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

### 3. Running the Frontend Application
```bash
# Dashboard UI (Port 5173)
cd dashboard-ui
npm install
npm run dev
```
Open your browser to `http://localhost:5173`. You can log in using Microsoft Entra ID, or use the local mock credentials (`admin` / `admin123`) to bypass SSO. New users will be pushed through the onboarding flow to configure their Splunk, Jira, and GitHub integrations.

---

## Pushing to GitHub (Git Submodule Architecture)

To push the entire monorepo to GitHub where each microservice acts as an independent Git Submodule (Sub Repository), follow these exact steps:

### Step A: Create the Repositories on GitHub
You will need to create 8 empty repositories in your GitHub account (do not initialize them with READMEs or `.gitignore` files):
1. `devops-pro-main` (The root monorepo)
2. `devops-pro-gateway`
3. `devops-pro-config`
4. `devops-pro-analyzer`
5. `devops-pro-collector`
6. `devops-pro-incident`
7. `devops-pro-scanner`
8. `devops-pro-ui`

### Step B: Push Sub-repositories
Run the following commands for **each** microservice directory. (Example shown for `gateway-service`):

```bash
cd gateway-service
# If not already initialized: git init && git add . && git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/devops-pro-gateway.git
git push -u origin main
cd ..
```
*(Repeat this process for `config-service`, `log-analyzer-service`, `log-collector-service`, `incident-service`, `repo-scanner-service`, and `dashboard-ui`, replacing the repository URL accordingly.)*

### Step C: Push the Root Monorepo
Once all sub-repositories are pushed to GitHub, navigate to the root directory (`devops-pro`) and link them as submodules:

```bash
# In the root directory (devops-pro)
# If not already initialized: git init && git add README.md pom.xml

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

When cloning the repository in the future, remember to use the `--recursive` flag to pull all submodules:
`git clone --recursive https://github.com/YOUR_USERNAME/devops-pro-main.git`
