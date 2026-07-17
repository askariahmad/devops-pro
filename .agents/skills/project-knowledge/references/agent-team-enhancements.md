# Agent Team Enhancements & Stack Analysis Reference

> **Topic**: Tech Stack & AI Agent Team Capabilities Analysis
> **Branch Context**: Cloud Migrations (`feat/azure-migration` and `feat/aws-migration`)
> **Generated**: 2026-07-15
> **Target Path**: `C:\Users\ahmad\IdeaProjects\devops-pro\.agents\skills\project-knowledge\references\agent-team-enhancements.md`

---

## 1. Executive Summary

This reference document performs a detailed analysis of the **DevOps Pro** repository technology stack (Spring Boot 3.3.x, React 18, Terraform, and Floci AWS/Azure local emulators). Based on this analysis, we identify technical gaps, production readiness limitations, and operational security concerns. 

To address these gaps, we propose expanding the agent development team with **3 new specialized personas**, introducing **6 new skill modules**, and establishing **5 new team policies/rules**. These enhancements will enable the AI agent team to transition the platform from a local emulator prototype to a secure, highly-available, and automated production-ready enterprise DevSecOps platform.

---

## 2. Tech Stack & Architecture Analysis

The DevOps Pro ecosystem is an AI-driven security and telemetry platform structured as a multi-tenant microservices system. Below is a breakdown of the core stack components:

### 2.1 Backend Core (Spring Boot & LangChain4j)
* **Framework**: Spring Boot 3.3.x, Java 21, Spring Cloud Gateway (acting as the edge controller with JWT authentication).
* **AI Orchestration**: LangChain4j (v0.35.0) integrated with local Ollama (`deepseek-coder`) or cloud providers (OpenAI GPT-4o, Anthropic Claude).
* **Gaps Identified**:
  * **OAuth2 / OIDC Security Validation**: The `gateway-service` implements custom JWT generation but accepts Microsoft Entra ID (SSO) login tokens on "good faith" (`AuthController.entraLogin()` extracts claims without cryptographically validating the signature against Microsoft's JWKS endpoint).
  * **Hardcoded Configurations**: Service-to-service endpoints and default secrets (JWT token generator keys) are hardcoded in YAML files or java source code.

### 2.2 Frontend (React + Vite)
* **Framework**: React 18, Vite, Tailwind CSS, Axios, and `@azure/msal-react` / `@azure/msal-browser` for SSO.
* **Gaps Identified**:
  * **CORS & Environment Management**: Hardcoded API endpoints in local development config require accessing the browser via `localhost:5173` strictly to prevent CORS failures.
  * **Static Configurations**: MSAL settings inside `authConfig.js` contain raw placeholder strings (`YOUR_ENTRA_CLIENT_ID`) which should be injected at build-time.

### 2.3 Databases & Event Streaming (MongoDB, Redis, Kafka)
* **Storage**: MongoDB (`devops_users`, `devops_config`, `devops_incidents`, `devops_notifications`).
* **Caching**: Redis (caching LLM analysis outputs by SHA-256 hash of the vulnerability signature to reduce API token costs).
* **Streaming**: Apache Kafka with Zookeeper (`raw-logs`, `enriched-alerts`, `incident-notifications`).
* **Gaps Identified**:
  * **PaaS Migration Deficit**: While Azure Cache for Redis has been successfully integrated via Terraform, MongoDB and Apache Kafka remain run-in-pod or local placeholders. They have not been migrated to cloud-native alternatives like **Azure Cosmos DB** (MongoDB API), **Amazon DocumentDB**, or **Azure Event Hubs / Amazon MSK**.

### 2.4 Infrastructure & Emulators (Terraform & Floci)
* **Orchestration**: Terraform scripts in the `terraform/` directory manage AKS/EKS cluster definitions, container registries (ACR/ECR), and Redis instances.
* **Emulation**: Local testing uses **Floci** (AWS LocalStack-compatible) and **Floci-AZ** (Azure emulator) listening on `http://localhost:4566` and `http://localhost:4577`.
* **Gaps Identified**:
  * **Terraform Syntax Bug**: `terraform/kubernetes.tf` references container images as `"{each.key}"` instead of HCL variable interpolation `"${each.key}"`. This is a blocking bug.
  * **Single-Node Risk**: Kubernetes clusters (AKS/EKS) are defined as single-node configurations, unsuitable for production high availability.
  * **No CI/CD Pipelines**: There are zero CI/CD configurations (no GitHub Actions or Azure DevOps YAML files). The deployment is managed manually via `deploy.ps1`.

---

## 3. Recommended Agent Persona Additions

While the existing agent list (17 personas) covers classic roles, the stack demands specific cloud-native DevSecOps specialization. We recommend adding the following three personas to `.agents/agents/`:

| New Agent Persona | Location | Description & System Prompt Focus |
|---|---|---|
| **DevSecOps / CI-CD Engineer** | `agents/devsecops-engineer` | **Role Focus**: Designing and hardening CI/CD pipelines (GitHub Actions, GitLab CI, Azure Pipelines). <br>**Key Tasks**: Writing workflows to run Terraform dry-runs, starting Floci emulators in test containers, checking code coverage, and implementing branch protection automations. |
| **Cloud Security & IAM Architect** | `agents/cloud-security-architect` | **Role Focus**: Implementing Least-Privilege IAM Policies, Key Vault integrations, and OIDC cryptographic validation.<br>**Key Tasks**: Fixing the Entra ID/Cognito SSO signature validation gap, configuring KMS keys, and managing Secrets Store CSI driver mount configs. |
| **Observability & SRE Specialist** | `agents/sre-specialist` | **Role Focus**: Configuring monitoring, alerting, telemetry aggregation, and service auto-scaling.<br>**Key Tasks**: Setting up Prometheus/Grafana dashboard HCLs, configuring Log Collector to consume real production Splunk streams, and tuning AKS/EKS HPA (Horizontal Pod Autoscaling). |

---

## 4. Recommended Skill Additions

To support developer and DevOps workstreams, we must create specialized skills under `.agents/skills/` containing reusable execution guides:

### 4.1 Skill: `ci-cd-automation` (`.agents/skills/ci-cd-automation/SKILL.md`)
* **Focus**: Actionable instructions for writing pipeline scripts, caching Docker layers, caching Maven repository builds, and starting Floci/LocalStack services inside runners.
* **Benefit**: Ensures any agent can quickly construct CI scripts to validate incoming PRs.

### 4.2 Skill: `cloud-database-migration` (`.agents/skills/cloud-database-migration/SKILL.md`)
* **Focus**: Actionable playbooks to migrate Spring Boot's Mongo configuration to **Azure Cosmos DB** (using Mongo API) and **Amazon DocumentDB**, including connection pool tuning (HikariCP, MongoDB Driver), SSL/TLS client settings, and retry mechanisms.

### 4.3 Skill: `cloud-messaging-streaming` (`.agents/skills/cloud-messaging-streaming/SKILL.md`)
* **Focus**: Connection instructions to migrate local Kafka streams to **Azure Event Hubs** (Kafka compatibility mode) and **Amazon MSK**, including SASL_SSL/JAAS authentication configs, VPC endpoint access, and consumer group setups.

### 4.4 Skill: `cloud-secrets-vault` (`.agents/skills/cloud-secrets-vault/SKILL.md`)
* **Focus**: Step-by-step instructions to externalize app configuration properties to **Azure Key Vault** or **AWS Secrets Manager** and mount them directly as Kubernetes Secrets via CSI drivers.

### 4.5 Skill: `oidc-security-validation` (`.agents/skills/oidc-security-validation/SKILL.md`)
* **Focus**: Security code snippets in Spring Security to configure OIDC token decoders using Entra ID and Cognito JWKS endpoints (`https://login.microsoftonline.com/{tenant}/discovery/v2.0/keys`) to cryptographically verify user claims.

### 4.6 Skill: `observability-sre-telemetry` (`.agents/skills/observability-sre-telemetry/SKILL.md`)
* **Focus**: Playbooks to set up Micrometer, Spring Boot Actuator endpoints, Prometheus scraping configurations, and Azure Monitor/CloudWatch metrics exports.

---

## 5. Recommended Project Rules & Policies

To enforce these best practices, the Scrum Master and development agents should enforce the following rules under `.agents/` or inside the team guides:

### 5.1 Secrets Management Policy (`.agents/SECRETS_POLICY.md`)
1. **Zero Secret Commits**: No actual API keys, private keys, or passwords may be committed to git.
2. **Local Placeholder Rule**: For local Floci environments, configurations must default to placeholder dummy credentials (e.g., `test` / `test` for AWS).
3. **Environment Injection**: Production configurations must resolve secrets using Spring Boot property placeholders pointing to environment variables (e.g., `${DB_PASSWORD}`) or Kubernetes mounts.

### 5.2 CI/CD Quality Gate Policy (`.agents/CICD_QUALITY_GATE_POLICY.md`)
1. **Pre-Merge Validation**: No PR may be merged into `feat/azure-migration` or `feat/aws-migration` without passing the automated CI check.
2. **Required CI Stages**: The CI workflow must include:
   * **Stage 1**: Linter & Static Code Analysis (SonarCloud).
   * **Stage 2**: Compile & Maven Unit Tests (Targeting >80% coverage).
   * **Stage 3**: Terraform validation (`terraform validate` and `terraform plan`).
   * **Stage 4**: Local emulator validation (using Floci container to check connection test endpoints).

### 5.3 OIDC Cryptographic Security Rule
*Added to `.agents/AGENTS.md` and `CODE_REVIEW_POLICY.md` under "Security":*
> [!IMPORTANT]
> **SSO Validation Rule**: Any single-sign-on implementation (such as Entra ID or AWS Cognito) MUST cryptographically validate token signatures against official JWKS keysets. "Trust-on-presentation" is prohibited.

### 5.4 Submodule Synchronization Policy
*Added to `TEAM_OPERATING_RULES.md` under "Git Workflow":*
> [!NOTE]
> **Submodule Rule**: When submitting a PR affecting a microservice submodule, the developer must:
> 1. Commit and push changes to the submodule repository branch.
> 2. Submit a PR inside the submodule repo.
> 3. Update the submodule reference pointer in the parent monorepo.
> 4. Reference the submodule PR link in the parent PR description.

### 5.5 Terraform Parameterization Policy
*Added to `AGENTS.md` under "Architecture Standards":*
> [!TIP]
> **Terraform Parameterization**: All provider endpoints, instance types, node counts, and network CIDRs must be parameterized using `variables.tf`. Hardcoded infrastructure values are restricted.

---

## 6. Gap-to-Action Plan Mapping

To assist the Scrum Master in allocating resources, this table details the actions required to resolve current gaps:

| Identified Technical Gap | Impact | Remediation Action | Assigned Agent Persona | Required Skill Module |
|---|---|---|---|---|
| Entra ID JWT verification is missing. | **Critical Security Flaw** (Allows authentication bypass/spoofing). | Implement JWT signature validation against JWKS endpoint in `gateway-service`. | @backend-developer | `oidc-security-validation` |
| Image reference syntax bug in `kubernetes.tf` (`"{each.key}"`). | **Deployment Blocker** (Kubernetes fails to pull images). | Correct syntax to `"${each.key}"` in the Terraform resource block. | @devops-engineer | `backend-architecture` |
| MongoDB and Kafka remain self-hosted containers. | **Production Risk** (No managed scaling or high-availability). | Refactor Terraform to provision Cosmos DB / DocumentDB and Event Hubs / MSK. | @devops-engineer | `cloud-database-migration` / `cloud-messaging-streaming` |
| No automated CI/CD pipeline files exist. | **Deployment Process Gaps** (Prone to manual human errors). | Write GitHub Actions YAML pipelines executing Maven builds and Terraform plans. | @devsecops-engineer *(New)* | `ci-cd-automation` |
| Secrets are hardcoded or written as plain config. | **Credentials Exposure Risk** (Security breach hazard). | Wire Spring Boot application config to resolve secrets from Azure Key Vault or AWS Secrets Manager. | @cloud-security-architect *(New)* | `cloud-secrets-vault` |
