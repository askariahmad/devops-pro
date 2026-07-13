# Local Development Setup Guide

Welcome to the DevOps Pro Microservices contributor guide! This document provides an **extremely detailed, step-by-step walkthrough** of how to set up, build, and run the entire ecosystem locally for active development.

---

## 1. Prerequisites 🛠️

Before you begin, ensure you have the following installed on your local machine:
- **Java Development Kit (JDK) 21**: All Spring Boot microservices are built targeting Java 21.
- **Apache Maven (3.8+)**: For building the Java backends.
- **Node.js (18+ or 20+) & npm**: For running the React/Vite frontend.
- **Docker & Docker Compose**: Required for running the backing infrastructure (MongoDB, Redis, Kafka, Zookeeper).
- **Git**: To clone the repository and its submodules.
- **IDE**: IntelliJ IDEA (Ultimate or Community) or Visual Studio Code are highly recommended.

---

## 2. Cloning the Repository 📥

Because this project utilizes Git submodules for each microservice, you must clone the repository recursively:

```bash
# Clone the root repository and all of its submodules
git clone --recursive https://github.com/askariahmad/devops-pro.git
cd devops-pro
```

*(If you already cloned it without `--recursive`, you can fetch the submodules by running: `git submodule update --init --recursive`)*

---

## 3. Starting the Backing Infrastructure (Databases & Message Brokers) 🐳

For local development, you do **not** want to run the microservices themselves inside Docker, because you want Hot Reloading and the ability to attach a debugger. However, you **do** want to run the databases and message brokers in Docker.

We have a dedicated Docker Compose file for this. 

1. Open your terminal in the root `devops-pro` folder.
2. Run the following command to start ONLY the infrastructure containers:

```bash
docker-compose up -d mongodb redis zookeeper kafka ollama-dev
```

3. **Verify the containers are running**:
```bash
docker ps
```
You should see:
- `devops-mongodb` running on port `27018` (mapped to `27017` internally).
- `devops-redis` running on port `6379`.
- `devops-kafka` running on port `9092`.
- `devops-zookeeper` running on port `2181`.
- `devops-ollama-dev` running on port `11434`.

---

## 4. Running the Backend Microservices (Spring Boot) ☕

You have 7 Spring Boot microservices. You can run them using your IDE (by running the `@SpringBootApplication` classes) or via the terminal using Maven. 

If running via the terminal, you must start them in a specific order to ensure dependencies (like the Config Service) are available:

### Service Start Order:
1. **Config Service** (Runs on `8082`)
2. **Gateway Service** (Runs on `8080`)
3. **Incident Service** (Runs on `8084`)
4. **Log Collector Service** (Runs on `8083`)
5. **Log Analyzer Service** (Runs on `8086`)
6. **Repo Scanner Service** (Runs on `8085`)
7. **Notification Service** (Runs on `8088`)

### How to run via Terminal:
Open a separate terminal tab for each service and run:

```bash
cd config-service
mvn spring-boot:run
```
*(Repeat this for all 7 services in the order listed above)*

### How to run via IntelliJ IDEA:
1. Open the root `devops-pro` folder in IntelliJ.
2. IntelliJ should detect it as a multi-module Maven project. Sync the Maven dependencies.
3. Open the **Services** tool window (`View -> Tool Windows -> Services`).
4. Add a new "Spring Boot" run configuration that includes all 7 Application classes (e.g., `ConfigApplication`, `GatewayApplication`, etc.).
5. Click **Start All**.

---

## 5. Running the Frontend Dashboard (React + Vite) ⚛️

The Dashboard UI is a modern Vite application. It communicates with the backend exclusively through the API Gateway (`localhost:8080`).

1. Open a new terminal tab and navigate to the frontend directory:
```bash
cd dashboard-ui
```

2. Install the Node.js dependencies:
```bash
npm install
```

3. Start the Vite development server (which includes Hot Module Replacement):
```bash
npm run dev
```

4. The terminal will output a local URL (usually `http://localhost:5173`). Open this URL in your browser.

---

## 6. Accessing the Application & Initial Data 🔑

Once everything is running, navigate to `http://localhost:5173`.

### Database Seeding
When the **Gateway Service** starts, it automatically seeds the local MongoDB with mock users and tenant configurations.

### Default Login Credentials
You can log into the local development environment using the following seeded credentials:
- **Email**: `sysadmin@devops.com`
- **Password**: `password123`

---

## 7. Working with the Mock Endpoints 🧪

To test the application without needing real API tokens for Splunk or SonarCloud:

1. Log into the Dashboard UI.
2. Go to the **Settings** page.
3. Ensure the LLM provider is set to use a mock or your preferred local LLM (like Ollama running `deepseek-coder`).
4. Ensure the Integration Settings for SonarCloud and Splunk are pointing to the internal mock endpoints (e.g., `http://localhost:8085/api/v1/scanner/mock` or `http://localhost:8083/mock/services/collector/event`).
5. **Important**: Since you are running the backend services on your host machine (not inside Docker), they will communicate with each other via `localhost:[port]` rather than the docker hostnames.

---

## 8. Common Local Development Pitfalls ⚠️

### MongoDB Connection Refused
- **Symptom**: Spring Boot services crash on startup with `MongoSocketOpenException`.
- **Fix**: Ensure your local Docker MongoDB is running. Note that our `docker-compose.yml` maps MongoDB to port **`27018`** on your host machine to avoid conflicting with any native Windows/Mac MongoDB installations. Your local Spring Boot `.env` or `application.yml` profiles should point to `mongodb://localhost:27018`.

### Kafka Broker Not Available
- **Symptom**: `Broker may not be available` warnings in logs.
- **Fix**: Ensure the `devops-kafka` and `devops-zookeeper` Docker containers are running. Kafka listens on `localhost:9092` from your host machine.

### API Gateway CORS Errors
- **Symptom**: The React frontend throws CORS errors in the browser console.
- **Fix**: The Gateway Service is configured to allow `http://localhost:5173`. If Vite assigns a different port (e.g., `5174`), you must either force Vite to use `5173` or update the CORS configuration in `gateway-service/src/main/resources/application.yml`.
