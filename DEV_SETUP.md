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

### Database Seeding
When the **Gateway Service** container starts up, it automatically executes a seeder script that populates the MongoDB container with mock users and tenant configurations.

### Default Login Credentials
Log into the local development environment using the seeded credentials:
- **Email**: `sysadmin@devops.com`
- **Password**: `password123`

---

## 7. Working with the Mock Endpoints 🧪

To test the application without needing real API tokens for external platforms:

1. Log into the Dashboard UI at `http://localhost:5173`.
2. Go to the **Settings** page.
3. Ensure the Integration Settings for SonarCloud and Splunk are pointing to the internal mock endpoints running inside the Docker network:
   - **SonarCloud Mock URL**: `http://repo-scanner-service:8085/api/v1/scanner/mock`
   - **Splunk Mock URL**: `http://log-collector-service:8083/mock/services/collector/event`
   
*(Notice how we use the Docker container names like `repo-scanner-service` instead of `localhost`! This is because the services communicate internally across the Docker bridge network).*

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
