# Azure Migration Architecture — DevOps Pro

> **Branch**: `feat/azure-migration`
> **Worktree Explored**: `subagent-Azure-Cloud-Deployment-Engineer-self-ccefd5f9`
> **Generated**: 2026-07-14

---

## Executive Summary

The `feat/azure-migration` branch migrates the DevOps Pro platform from a raw Docker Compose local stack to a **fully Azure-hosted, Terraform-managed** deployment. The core strategy is:

1. **Floci-AZ emulator** (`docker run floci/floci-az:latest`) replaces docker-compose for all Azure services during local development and CI testing — no real Azure subscription charges.
2. **Terraform** (`hashicorp/azurerm ~> 3.0`) provisions all resources against the Floci-AZ emulator at `http://localhost:4577`.
3. **Azure Kubernetes Service (AKS)** hosts all 8 application containers (7 Spring Boot microservices + 1 React/Nginx frontend).
4. **Azure Container Registry (ACR)** stores all Docker images pushed during CI.
5. **Azure Cache for Redis** replaces the locally managed Redis container — now a fully managed PaaS service.
6. **Microsoft Entra ID (Azure AD) via MSAL** provides SSO login for the dashboard, supplementing the existing username/password flow.

The deployment is triggered by running `./deploy.ps1 -Cloud azure`, which starts the emulator, then runs `terraform init && terraform apply -auto-approve`.

---

## Cloud Services Used

| Azure Service | Terraform Resource | Purpose |
|---|---|---|
| **Resource Group** | `azurerm_resource_group.rg` | Logical container for all DevOps Pro Azure resources, region: `East US` |
| **Azure Kubernetes Service (AKS)** | `azurerm_kubernetes_cluster.aks` | Hosts all 8 microservice workloads; `Standard_DS2_v2` node, `SystemAssigned` managed identity |
| **Azure Container Registry (ACR)** | `azurerm_container_registry.acr` | Registry (`devopsproacr.azurecr.io`), SKU: `Standard`, admin enabled for image pulls |
| **Azure Cache for Redis** | `azurerm_redis_cache.redis` | Managed Redis for LLM result caching and session data; SKU: `Standard`, capacity C1, TLS 1.2+ only |
| **Microsoft Entra ID (Azure AD)** | *(External — MSAL browser)* | SSO login via MSAL popup; `User.Read` scope, tokens exchanged at `/api/v1/auth/entra-login` |
| **Floci-AZ Emulator** | *(Runtime — Docker)* | Local Azure emulator at `http://localhost:4577`, simulates all `azurerm` API endpoints for CI/dev |

> **Notable omissions at this stage**: Azure DB for PostgreSQL, Azure Service Bus / Event Hubs, and Azure Key Vault are **not yet defined** in the Terraform config. The platform still uses Kafka (from the base stack) and MongoDB (local/in-pod). These are candidates for future migration phases.

---

## Terraform Resource Breakdown

### File: `terraform/main.tf`

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
  # All four credentials are placeholder UUIDs
  tenant_id       = "00000000-0000-0000-0000-000000000000"
  subscription_id = "00000000-0000-0000-0000-000000000000"
  client_id       = "00000000-0000-0000-0000-000000000000"
  client_secret   = "00000000-0000-0000-0000-000000000000"
  # Routes all ARM calls to the Floci-AZ emulator
  metadata_host   = "http://localhost:4577"
}
```

**Key resources declared:**

| Resource | Name | Notes |
|---|---|---|
| `azurerm_resource_group` | `devops-pro-rg` | East US |
| `azurerm_kubernetes_cluster` | `devops-pro-aks` | 1 node, `Standard_DS2_v2`, `SystemAssigned` identity |
| `azurerm_container_registry` | `devopsproacr` | Standard SKU, admin enabled |
| `azurerm_redis_cache` | `devops-redis-cache` | Standard C1, SSL only, TLS 1.2+ |

**Outputs:**
- `kubeconfig` (sensitive) — raw kubeconfig for `devops-pro-aks`
- `redis_primary_connection_string` (sensitive) — primary Redis connection string

---

### File: `terraform/kubernetes.tf`

This file provisions the Kubernetes Deployment and Service objects **inside the AKS cluster** using the `kubernetes` Terraform provider, configured with the AKS kubeconfig credentials.

**Services deployed via `for_each` loop:**

| Service | Kubernetes Service Type |
|---|---|
| `dashboard-ui` | `LoadBalancer` (external) |
| `gateway-service` | `LoadBalancer` (external) |
| `config-service` | `ClusterIP` (internal) |
| `incident-service` | `ClusterIP` (internal) |
| `repo-scanner-service` | `ClusterIP` (internal) |
| `log-analyzer-service` | `ClusterIP` (internal) |
| `log-collector-service` | `ClusterIP` (internal) |
| `notification-service` | `ClusterIP` (internal) |

**Image pattern**: `devopsproacr.azurecr.io/{service-name}:latest`

> Known Bug: The image reference uses a Terraform string literal `"{each.key}"` instead of proper HCL interpolation `"${each.key}"`. This needs to be corrected before actual image pulls will work.

**Environment variables injected into all pods:**

| Variable | Value | Purpose |
|---|---|---|
| `DB_HOST` | `http://localhost:4577` | Points to Floci emulator (placeholder for real MongoDB URI) |
| `KAFKA_BROKERS` | `http://localhost:4577` | Points to Floci emulator (placeholder for real Kafka/Service Bus) |
| `AUTH_URL` | `http://localhost:4577` | Placeholder for Entra ID auth endpoint |
| `SPRING_DATA_REDIS_HOST` | `azurerm_redis_cache.redis.hostname` | **Actual** Azure Cache for Redis hostname (dynamic Terraform output) |

**Port mapping**: All services expose port `80` to container port `8080`.

---

## Backend Microservices Overview

All services are Spring Boot 3.3.x, Java 21, multi-module Maven project (`com.devops` group, `1.0.0-SNAPSHOT`), LangChain4j 0.35.0 for AI.

| Service | Port | DB | Kafka Role | Service-to-Service Calls |
|---|---|---|---|---|
| `gateway-service` | `8080` | MongoDB (`devops-pro-auth`) | None | Routes to all services below |
| `config-service` | `8082` | MongoDB (`devops_config`) | None | Consumed by scanner, collector, analyzer, incident |
| `log-collector-service` | `8083` | None | **Producer** → `raw-logs` | Calls analyzer at `:8081`, config at `:8082` |
| `log-analyzer-service` | `8081` | None | **Consumer** from `raw-logs`, **Producer** → `enriched-alerts` | Calls incident at `:8084`, config at `:8082` |
| `repo-scanner-service` | `8085` | None | **Producer** → `enriched-alerts` | Calls config at `:8082`, incident at `:8084`; Uses Redis |
| `incident-service` | `8084` | MongoDB (`devops_incidents`) | **Consumer** from `enriched-alerts`, **Producer** → `incident-notifications` | Calls config at `:8082`; Uses Redis |
| `notification-service` | `8086` | MongoDB (`devops_notifications`) | **Consumer** from `incident-notifications` | Dispatches webhooks/Slack |

### Kafka Topics

| Topic | Producer | Consumer | Purpose |
|---|---|---|---|
| `raw-logs` | `log-collector-service` | `log-analyzer-service` | Raw telemetry from Splunk/Datadog |
| `enriched-alerts` | `log-analyzer-service`, `repo-scanner-service` | `incident-service` | AI-enriched anomaly/vulnerability events |
| `incident-notifications` | `incident-service` | `notification-service` | Trigger events for Webhook/Slack dispatch |

### MongoDB Databases

| Database | Owner Service | Entities Stored |
|---|---|---|
| `devops-pro-auth` | `gateway-service` | Users, credentials, RBAC roles, tenant IDs |
| `devops_config` | `config-service` | Tenant configs (GitHub, Sonar, Splunk tokens, LLM settings) |
| `devops_incidents` | `incident-service` | Deduplicated incidents, AI explanations, git diff patches |
| `devops_notifications` | `notification-service` | Notification history and status |

### Redis Usage
- **`repo-scanner-service`**: Caches LLM analysis results keyed by SHA-256 hash of vulnerability signature (TTL: 7 days). Cache miss triggers LLM call; cache hit returns stored result.
- **`incident-service`**: Also has Redis configured (likely for deduplication fingerprinting).
- **Azure target**: `SPRING_DATA_REDIS_HOST` is the only env var already pointing to a real Azure resource.

---

## Frontend Authentication Mechanism (MSAL / Entra ID)

### Library Versions
- `@azure/msal-browser` v5.17.0
- `@azure/msal-react` v5.5.2

### Configuration (`src/authConfig.js`)

```js
export const msalConfig = {
  auth: {
    clientId: "YOUR_ENTRA_CLIENT_ID",     // To be filled by operator
    authority: "https://login.microsoftonline.com/YOUR_TENANT_ID",
    redirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  }
};

export const loginRequest = {
  scopes: ["User.Read"]
};
```

`clientId` and `YOUR_TENANT_ID` are placeholders. The operator must register an App Registration in Entra ID and populate these values before SSO login works.

### MSAL Bootstrap (`src/main.jsx`)

```jsx
const msalInstance = new PublicClientApplication(msalConfig);
// Wraps the entire app in MsalProvider
<MsalProvider instance={msalInstance}><App /></MsalProvider>
```

### Dual Login Paths (`src/components/LoginScreen.jsx`)

#### Path 1: Microsoft Entra ID (SSO)
1. User clicks **"Microsoft Entra ID"** button.
2. MSAL `loginPopup(loginRequest)` is called, returning `accessToken` + `account.username`.
3. Frontend POSTs to `POST /api/v1/auth/entra-login` with `{ entraToken, username }`.
4. Gateway's `AuthController.entraLogin()` extracts the email, derives `tenantId` from email domain (`@company.com` → `company-com-tenant`), assigns a default role (`ROLE_DEVELOPER_VIEWER`), and generates a **DevOps Pro JWT**.
5. JWT is stored in `localStorage` and used for all subsequent API calls.

> **Security Note**: The backend does **not** validate the Entra `accessToken` cryptographically in the current implementation. The token is accepted on good faith; the Entra identity is used only for email/username extraction and tenant derivation. This must be hardened for production.

#### Path 2: Username/Password (Legacy)
1. User submits the email/password form.
2. Frontend POSTs to `POST /api/v1/auth/login` or `POST /api/v1/auth/signup`.
3. Gateway validates credentials against MongoDB and returns a DevOps Pro JWT.

### JWT Structure
The Gateway generates JWTs containing `username`, `tenantId`, and `role` claims. The gateway validates these on every inbound request and injects `X-Tenant-Id` as a downstream header to enforce multi-tenancy.

---

## Deployment Flow

### Local / CI (Floci-AZ Emulator)

```
./deploy.ps1 -Cloud azure
    |
    |-- [1/2] Notes: Redis is now managed by Azure (no external services to start)
    |
    |-- [2/2] Start Floci-AZ emulator
    |         docker rm -f floci-az
    |         docker run -d -p 4577:4577 --name floci-az floci/floci-az:latest
    |         (wait 5s for initialization)
    |
    +-- [3/3] Terraform
              terraform init
              terraform apply -auto-approve
              -> Creates: Resource Group, AKS, ACR, Redis Cache
              -> Deploys: 8 Kubernetes Deployments + Services inside AKS
```

### Production (Real Azure)
Swap the `metadata_host` placeholder in `main.tf` with the real ARM endpoint, provide real `tenant_id`, `subscription_id`, `client_id`, and `client_secret` (via environment variables or secrets backend, not hardcoded), then run `terraform apply`.

### Docker Image Build & Push (Pre-Terraform)
Each Spring Boot service has a multi-stage Dockerfile:
- **Stage 1** (`maven:3.9.6-eclipse-temurin-21-alpine`): Builds the Spring Boot fat JAR.
- **Stage 2** (`eclipse-temurin:21-jre-alpine`): Runs the JAR.

Frontend (`dashboard-ui`):
- **Stage 1** (`node:20-alpine`): Runs `npm ci && npm run build` to generate `/app/dist`.
- **Stage 2** (`nginx:alpine`): Serves the static bundle via Nginx with SPA fallback routing.

Images must be pushed to `devopsproacr.azurecr.io` before `terraform apply` references them in AKS pods.

---

## Key Environment Variables and Secrets

### Terraform Provider Credentials (currently placeholder UUIDs)

| Variable | Purpose |
|---|---|
| `tenant_id` | Azure Active Directory tenant ID |
| `subscription_id` | Azure subscription to deploy into |
| `client_id` | Service Principal (App Registration) client ID |
| `client_secret` | Service Principal secret |

### Pod-Level Environment Variables (from `kubernetes.tf` locals.env_vars)

| Variable | Current Value | Production Target |
|---|---|---|
| `DB_HOST` | `http://localhost:4577` | Azure Cosmos DB (Mongo API) or MongoDB Atlas URI |
| `KAFKA_BROKERS` | `http://localhost:4577` | Azure Event Hubs connection string or Kafka brokers |
| `AUTH_URL` | `http://localhost:4577` | Entra ID / Auth service URL |
| `SPRING_DATA_REDIS_HOST` | `azurerm_redis_cache.redis.hostname` (dynamic) | Already wired correctly |

### Secrets Not Yet in Terraform (Needed for Full Operation)

| Secret | Service | Purpose |
|---|---|---|
| `jwt.secret` (in `application.yml`) | `gateway-service` | JWT signing key (hardcoded hex — must be externalized) |
| `GITHUB_TOKEN` | `repo-scanner-service` | GitHub PAT for Auto-Fix PR creation |
| `SONAR_TOKEN` | `repo-scanner-service` | SonarCloud/SonarQube API token |
| `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` | `log-analyzer-service`, `repo-scanner-service` | LLM provider keys |
| `SPLUNK_HEC_TOKEN` | `log-collector-service` | Splunk HTTP Event Collector token |
| `ENTRA_CLIENT_ID` | `dashboard-ui` (MSAL config) | Azure App Registration client ID |
| `ENTRA_TENANT_ID` | `dashboard-ui` (MSAL config) | Azure AD tenant ID |

> **Recommendation**: Store all runtime secrets in **Azure Key Vault** and mount them as Kubernetes Secrets via the AKS Key Vault CSI driver. This is not yet implemented.

---

## Vite Frontend Environment Config

| File | `VITE_API_BASE_URL` | `VITE_ENV` |
|---|---|---|
| `.env.development` | `http://localhost:8080/api/v1` | `dev` |
| `.env.production` | `https://api.devops-pro.com/api/v1` | `prod` |

The AKS `LoadBalancer` for `gateway-service` would need a DNS name matching `api.devops-pro.com` for the production build to work without changes.

---

## CI/CD Configuration

**No CI/CD pipeline files were found** in either the worktree or the main repo (no `.github/workflows/`, `Jenkinsfile`, or Azure DevOps pipelines exist at this time). The deployment is entirely manual via `deploy.ps1`.

**Recommended next step**: Add a GitHub Actions workflow or Azure DevOps pipeline to:
1. Run `mvn clean package` to build JARs.
2. Run `docker build & push` to push images to ACR.
3. Run `terraform apply` to update AKS workloads.

---

## Notable Patterns and Design Decisions

### 1. Floci-AZ as Azure Emulator
The project uses `floci/floci-az` (listening on port `4577`) as a local Azure emulator, analogous to LocalStack for AWS. This allows full Terraform IaC development and testing without real Azure costs. The `metadata_host` override in the `azurerm` provider is the key mechanism.

### 2. Terraform Manages Both Infrastructure and Application Deployment
Unlike typical patterns where Terraform manages infrastructure only and Helm/kubectl manages application deployments, this project uses Terraform's `kubernetes` provider directly. This is a valid approach for simple workloads but reduces flexibility compared to a separate Helm chart or GitOps CD tool.

### 3. Dual Authentication Strategy
The frontend supports both classic username/password (backed by MongoDB) and Entra ID SSO (backed by MSAL). The Entra flow on the backend currently performs "trust on presentation" — the Entra token is used only for identity assertion, not validated via Microsoft's JWKS endpoint. This should be hardened before production.

### 4. Redis Fully Migrated; Kafka and MongoDB Still Placeholder
The most significant Azure PaaS adoption is Redis -> Azure Cache for Redis (`SPRING_DATA_REDIS_HOST` is already dynamically populated from the Terraform output). MongoDB and Kafka remain as in-pod/placeholder references. Future migration phases should replace these with Azure Cosmos DB (MongoDB API) and Azure Event Hubs.

### 5. Single-Node AKS Cluster
The AKS cluster is provisioned with `node_count = 1` and `Standard_DS2_v2`. For production, this needs to be a node pool with autoscaling and at least 3 nodes for high availability.

### 6. Multi-Tenancy via JWT + X-Tenant-Id Header
The API Gateway validates every request's JWT, extracts the `tenantId` claim, and injects `X-Tenant-Id` as a forwarded header. All downstream services use this header for data partitioning in MongoDB. This pattern is preserved across the Azure migration.

### 7. Git Submodules Architecture
Each microservice is a separate Git submodule with its own repository. The root `pom.xml` is the Maven parent aggregator. The `devops-pro` repo is the monorepo coordinator.

### 8. Known Bug: Image Reference in kubernetes.tf
The container image value uses `"{each.key}"` (literal string) instead of `"${each.key}"` (HCL interpolation). This means AKS pods would try to pull an image literally named `{each.key}:latest` rather than the correct service-specific image. This is a blocking bug that must be fixed before the Kubernetes deployment will work.

---

## Architecture Diagram (ASCII)

```
                    +---------------------------------------------+
                    |           Azure (East US)                   |
                    |     Resource Group: devops-pro-rg           |
                    |                                             |
                    |  +--------------------------------------+   |
                    |  |  AKS Cluster: devops-pro-aks         |   |
                    |  |  (Standard_DS2_v2, SystemAssigned)   |   |
                    |  |                                      |   |
                    |  |  LoadBalancer Services:              |   |
                    |  |  +-------------+  +--------------+  |   |
                    |  |  |dashboard-ui |  |gateway-svc   |  |   |
                    |  |  |(React/Nginx)|  |(SCG + JWT)   |  |   |
                    |  |  +-------------+  +------+-------+  |   |
                    |  |                          |           |   |
                    |  |  ClusterIP Services:     |           |   |
                    |  |  +---------+  +----------v-------+  |   |
                    |  |  |config   |  |incident-service  |  |   |
                    |  |  |svc:8082 |  |svc:8084 (Mongo)  |  |   |
                    |  |  +---------+  +------------------+  |   |
                    |  |  +----------------+  +----------+  |   |
                    |  |  |log-collector   |  |repo-scan  |  |   |
                    |  |  |svc:8083        |  |svc:8085   |  |   |
                    |  |  +----------------+  +----------+  |   |
                    |  |  +----------------+  +----------+  |   |
                    |  |  |log-analyzer    |  |notif-svc |  |   |
                    |  |  |svc:8081        |  |svc:8086  |  |   |
                    |  |  +----------------+  +----------+  |   |
                    |  +--------------------------------------+   |
                    |                                             |
                    |  +-----------------+  +-----------------+  |
                    |  | ACR:            |  | Redis Cache:    |  |
                    |  | devopsproacr    |  | devops-redis-   |  |
                    |  | .azurecr.io     |  | cache (Std C1)  |  |
                    |  +-----------------+  +-----------------+  |
                    +---------------------------------------------+

  External:             Microsoft Entra ID
  +------------+        (MSAL popup login)
  | User/Browser|<------------------------------->
  +------------+
```
