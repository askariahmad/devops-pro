# Local Development Setup Guide

Welcome to the DevOps Pro Microservices contributor guide! This document provides an **extremely detailed, step-by-step walkthrough** of how to set up, build, and run the entire ecosystem locally for active development. 

The entire platform is built around a **fully Dockerized** workflow. You do not need to install Java, Maven, or Node.js on your local machine to run the application—Docker handles everything!

---

## 1. Prerequisites 🛠️

Before you begin, ensure you have the following installed on your local machine:
- **Docker Desktop** (v4.20+) or Docker Engine (v24.0+)
- **Docker Compose** (v2.20+)
- **Git**: To clone the repository and its submodules.
- At least **8GB of RAM** allocated to Docker (12GB+ recommended) to comfortably run all microservices, databases, and LLM containers concurrently.

---

## 2. Cloning the Repository 📥

Because this project utilizes Git submodules for each microservice, you must clone the repository recursively so that you pull the source code for all services:

```bash
# Clone the root repository and all of its submodules
git clone --recursive https://github.com/askariahmad/devops-pro.git
cd devops-pro
```

*(If you already cloned it without `--recursive`, you can fetch the submodules by running: `git submodule update --init --recursive`)*

---

## 3. Building and Starting the Platform 🐳

We use a combination of `docker-compose.yml` (base infrastructure) and `docker-compose.dev.yml` (development overrides) to spin up the entire ecosystem.

1. Open your terminal in the root `devops-pro` folder.
2. Run the following command to build the Docker images from the local submodules and start all containers in the background:

```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
```

### What happens during this command?
- Docker will build the Spring Boot `.jar` files inside multi-stage `Dockerfile`s using Maven.
- It will build the React `dashboard-ui` into a static bundle served by Nginx.
- It will pull and start all backing infrastructure (`mongo`, `redis`, `kafka`, `zookeeper`, `ollama-dev`).
- It will orchestrate the startup of all 7 backend microservices, attaching them to a shared custom Docker network (`devops-network`).

3. **Verify the containers are running**:
```bash
docker ps
```
You should see around 13 containers running successfully, including:
- `devops-dashboard-ui` (Port `5173`)
- `devops-gateway-service` (Port `8080`)
- `devops-mongodb` (Port `27018`)
- `devops-kafka` (Port `9092`)

---

## 4. Monitoring Logs During Development 📜

Since everything runs inside Docker, you will use Docker commands to monitor the logs of specific services when debugging:

- **View API Gateway Logs**:
  ```bash
  docker logs -f devops-gateway-service
  ```
- **View Repo Scanner Logs**:
  ```bash
  docker logs -f devops-repo-scanner-service
  ```
- **View All Logs Simultaneously**:
  ```bash
  docker-compose logs -f
  ```

---

## 5. Rebuilding After Making Code Changes 🔄

When you make changes to the source code of any microservice (e.g., modifying a Java class in `log-analyzer-service`), you need to rebuild that specific Docker container. You do **not** need to rebuild the entire platform.

**Example: Rebuilding only the Log Analyzer Service**
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build log-analyzer-service
```
This will quickly re-compile the Java code, create a new Docker image, and recreate just that specific container while leaving the rest of the ecosystem untouched.

---

## 6. Accessing the Application & Initial Data 🔑

Once all containers are healthy, navigate to the frontend:
- **URL**: `http://localhost:5173`

### Database Seeding & Test Users
When the **Gateway Service** container starts up, it automatically executes a seeder script that populates the MongoDB container with multiple test users and varying Role-Based Access Control (RBAC) levels. 

You can log into the local development environment using any of the following seeded credentials. **The password for all accounts is `password123`.**

| Email | Role | Tenant ID | Permissions |
|-------|------|-----------|-------------|
| `sysadmin@devops.com` | `ROLE_SYSTEM_ADMIN` | `devops-com-tenant` | Full access to settings, auto-fix, and all incidents. |
| `tenantadmin@devops.com` | `ROLE_TENANT_ADMIN` | `devops-com-tenant` | Can configure tenant-specific rules. |
| `security@devops.com` | `ROLE_SECURITY_ENGINEER` | `devops-com-tenant` | Can view and trigger scans, but cannot change global settings. |
| `dev@devops.com` | `ROLE_DEVELOPER_VIEWER` | `devops-com-tenant` | Read-only view of dashboards and incidents. |
| `realuser@devops.com` | `ROLE_SYSTEM_ADMIN` | `real-tenant` | An isolated secondary tenant to test multi-tenant data partitioning. |

---

## 7. Connecting Integrations (Mock vs Real) 🔌

The application allows you to seamlessly toggle between internal Mock data (for fast, offline UI development) and real, live platforms.

### 7.1 Using the Internal Mock Endpoints
To test the application without needing real API tokens:
1. Log into the Dashboard UI at `http://localhost:5173`.
2. Go to the **Settings** page.
3. Ensure the Integration Settings are pointing to the internal mock endpoints running inside the Docker network:
   - **SonarCloud Mock URL**: `http://repo-scanner-service:8085/api/v1/scanner/mock`
   - **Splunk Mock URL**: `http://log-collector-service:8083/mock/services/collector/event`
   
*(Notice how we use the Docker container names like `repo-scanner-service` instead of `localhost`! This is because the services communicate internally across the Docker bridge network).*

### 7.2 Connecting Real Integrations
If you want the platform to interact with live production code, you can easily connect your real instances:

#### A. Real GitHub Integration (Auto-Fix)
To enable the AI to actually create branches, commit code, and open Pull Requests:
1. Go to your GitHub account -> **Settings** -> **Developer Settings** -> **Personal Access Tokens (Tokens (classic))**.
2. **If using a Classic Token**, check the following exact boxes:
   - `[x] repo` (Full control of private repositories)
3. **If using Fine-Grained Tokens (Recommended)**, set the following exact Repository Permissions:
   - **Contents**: `Read and write` (to fetch source code and push new commits)
   - **Pull requests**: `Read and write` (to open the auto-fix PR)
   - **Metadata**: `Read-only` (mandatory default)
4. In the DevOps Pro UI, go to **Settings**, paste this token into the **GitHub Personal Access Token** field, and hit Save.

#### B. Real SonarQube / SonarCloud Integration
1. In SonarCloud, go to **My Account** -> **Security** -> **Generate Tokens**.
2. Create a "User Token" and copy it. 
3. **Required Exact Permissions**: The user who generates this token must have the following project-level permissions in SonarQube/SonarCloud Administration:
   - `[x] Browse` (Required to view the project)
   - `[x] See Source Code` (Required to fetch the vulnerable lines of code)
   - `[x] Administer Issues` (Optional, but recommended if you plan to auto-resolve issues later)
4. In the DevOps Pro UI, change the **SonarQube URL** to `https://sonarcloud.io` (or your on-premise URL).
5. Paste the generated token into the **SonarQube Token** field and save.

#### C. Real Splunk / Datadog Integration
1. In Splunk Enterprise, go to **Settings** -> **Data Inputs** -> **HTTP Event Collector**.
2. Click **New Token**.
3. **Required Exact Configuration**:
   - **Enable Indexer Acknowledgment**: `Unchecked` (or checked based on your reliability needs)
   - **Source type**: Set to `_json` or `Automatic`
   - **Allowed Indexes**: Select `main` (or whichever specific index you want alerts routed to)
   - **Default Index**: Set to `main`
4. In the DevOps Pro UI, change the **Splunk HEC URL** to your real Splunk instance (e.g., `https://splunk.yourcompany.com:8088/services/collector/event`).
5. Paste the HEC token into the **Splunk Token** field and save.

#### D. Real LLM Providers (OpenAI vs Ollama)
By default, the `docker-compose.yml` spins up a local Ollama container running `deepseek-coder`. 
If you want to use OpenAI (GPT-4o) for faster, more accurate vulnerability analysis:
1. Go to the UI **Settings** -> **LLM Provider**.
2. Select **OpenAI** from the dropdown.
3. Enter your real `sk-...` API key into the **OpenAI API Key** field.
4. **Required Exact Permissions**: Standard API keys require no special scopes. However, if using a **Project API Key**, ensure it has:
   - **Model Access**: `Read/Write` access specifically to the `gpt-4o` or `gpt-4o-mini` models.
4. Click **Test LLM Connection**. The config service will make a live call to `api.openai.com` to verify your key.
5. Hit **Save**. The next time you trigger a Repo Scan, the LangChain4j module will route the prompt to GPT-4o!

---

## 8. Common Local Development Pitfalls ⚠️

### API Gateway CORS Errors
- **Symptom**: The React frontend throws CORS errors in the browser console.
- **Fix**: The Gateway Service is configured to allow requests from `http://localhost:5173`. Ensure you are accessing the UI exactly via `http://localhost:5173` and not `127.0.0.1` or another port.

### Kafka Broker Disconnects
- **Symptom**: Microservices output `Broker may not be available` warnings and crash.
- **Fix**: Kafka requires a few seconds to fully initialize and register with Zookeeper. If a microservice crashes because it started before Kafka was ready, simply restart the crashed service:
  ```bash
  docker restart devops-incident-service
  ```

### Out of Memory (OOM) Container Kills
- **Symptom**: A container randomly stops or `docker ps` shows it as `Exited (137)`.
- **Fix**: This means Docker Desktop ran out of allocated memory. 12+ containers (especially Spring Boot + LLMs) are memory intensive. Increase your Docker Engine memory limit in the Docker Desktop settings to at least 10GB.
