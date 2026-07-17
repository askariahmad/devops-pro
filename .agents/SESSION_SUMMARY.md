# Session Summary: Deployment Script Refactoring & MSAL SSL Fixes

**Date**: July 17, 2026

## 1. Problem Solved
- **Insecure MSAL Authority Error**: The dashboard-ui was crashing with `ClientConfigurationError: authority_uri_insecure` because MSAL.js in the browser requires HTTPS for local development emulators when validating authorities. We fixed the scheme from `http` to `https` in `dashboard-ui/src/authConfig.js` since the Floci-AZ emulator runs with TLS enabled.
- **PowerShell Script Terminating on Warnings**: When `$ErrorActionPreference = "Stop"` was configured, PowerShell converted native CLI warning output (from `kubectl` or `docker`) into terminating `NativeCommandError` exceptions, crashing the script. We wrapped these CLI calls in local error action overrides (`$ErrorActionPreference = "Continue"`).
- **LoadBalancer Teardown & Deployment Conflicts**: Incremental redeployments got stuck or crashed with `"already exists"` and `"object is being deleted"` errors.
  - *Conflict check*: We implemented an offline check that scans the `terraform.tfstate` file and force-deletes only conflicting untracked *deployments*, leaving stable `LoadBalancer` *services* alone (preventing network port-binding hangs).
  - *Non-Blocking Apply*: Added `wait_for_rollout = false` and `wait_for_load_balancer = false` to Terraform.
  - *Real-time Pod Monitoring*: Replaced blocking Terraform checks with an active diagnostics loop in `deploy.ps1` that streams logs and event descriptions instantly if a pod gets stuck in waiting states. Increased the wait timeout from 30s to 60s to prevent false warnings for slow Spring Boot container startup phases.
  - *Auto-Start Cluster Check*: Added validation checks to detect cluster connectivity and auto-start managers (`minikube`, `k3d`, `kind`) if no active local cluster is found.
- **Service Container Port Mismatch**: Backend services like `config-service` (listening on `8082`), `log-collector-service` (listening on `8083`), etc. were failing health probes and returning `Connection refused` (refusing connections on port `80`) because the Terraform Kubernetes service definitions mapped their `target_port` globally to `8080` instead of their actual configured ports. We added a port mapping lookup in `kubernetes.tf` to assign target ports dynamically.
- **Missing Spring Actuator Dependency**: The microservices were starting successfully but failing Kubernetes health checks with `404 Not Found` because none of the Spring Boot projects had the `spring-boot-starter-actuator` dependency defined. We added Actuator to the root `pom.xml` so all services inherit it and expose the `/actuator/health` endpoint.
- **Local LoadBalancer Port Collision**: In local Kubernetes (e.g. Kind/Docker Desktop), multiple `LoadBalancer` services trying to expose port `80` (like `dashboard-ui` and `gateway-service`) collide because they attempt to bind to the same host port `80`. Furthermore, the React code calls the API gateway at `http://localhost:8080`. We resolved this by changing `gateway-service` exposed port to `8080` and `dashboard-ui` to `80`.

## 2. Changes Made
- **[deploy.ps1](file:///c:/Users/ahmad/IdeaProjects/devops-pro/deploy.ps1)**: Completely rewritten from scratch. Clean, modular functions with try-finally error-action overrides, cluster provisioning, offline tfstate index parsing, and live diagnostics logging.
- **[kubernetes.tf](file:///c:/Users/ahmad/IdeaProjects/devops-pro/terraform/kubernetes.tf)**: Added `wait_for_rollout = false` to deployments, `wait_for_load_balancer = false` to services, a `service_ports` map lookup under `locals`, and updated the probes and target port mappings to query the actual container port dynamically.
- **[authConfig.js](file:///c:/Users/ahmad/IdeaProjects/devops-pro/dashboard-ui/src/authConfig.js)**: Configured local authority URI to use `https://localhost:4577/...`.
- **[AGENTS.md](file:///c:/Users/ahmad/IdeaProjects/devops-pro/.agents/AGENTS.md)**: Cleaned up inline troubleshooting logs and linked them to the new custom skill.
- **[SKILL.md](file:///c:/Users/ahmad/IdeaProjects/devops-pro/.agents/skills/lessons-learned/SKILL.md)**: Created a new custom skill `lessons-learned` capturing DevOps, PowerShell, and Kubernetes local development runbooks.
- **[Jenkinsfile](file:///c:/Users/ahmad/IdeaProjects/devops-pro/Jenkinsfile)**: Created a declarative CI/CD pipeline containing parallel builds, testing, and rollout diagnostics stages per service.

