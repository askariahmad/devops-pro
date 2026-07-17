---
name: lessons-learned
description: "Best practices, troubleshooting tips, and lessons learned for DevOps-Pro local Kubernetes, Docker, PowerShell scripting, and MSAL OAuth configuration."
---

# Skill: Lessons Learned & Troubleshooting Runbook

This skill compiles all critical lessons learned and troubleshooting procedures discovered during the development of local deployment automation, emulators, and local cloud configurations in the DevOps-Pro project.

## 1. PowerShell Native Command Executions
When `$ErrorActionPreference = "Stop"` is configured in automated scripts, PowerShell converts native CLI warning/error messages on `stderr` (e.g. from `kubectl` or `docker`) into terminating `NativeCommandError` exceptions, crashing the script.
* **Workaround**: Scope `$ErrorActionPreference = "Continue"` locally or wrap the native commands inside a `try-finally` block:
  ```powershell
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
      & kubectl delete deployment my-app --ignore-not-found --grace-period=0 --force
  } finally {
      $ErrorActionPreference = $oldEap
  }
  ```

## 2. Local Kubernetes LoadBalancer Hangs
In single-node local Kubernetes clusters (e.g., Docker Desktop, Minikube), `LoadBalancer` services often hang indefinitely in a `Terminating` state because host network/port bindings fail to release.
* **Teardown Workaround**:
  1. Patch the service type to `ClusterIP` to release host ports instantly:
     `kubectl patch service <service-name> -p '{"spec":{"type":"ClusterIP"}}' --type=merge`
  2. Clear resource finalizers to bypass deletion locks:
     `kubectl patch service <service-name> -p '{"metadata":{"finalizers":null}}' --type=merge`
  3. Force delete:
     `kubectl delete service <service-name> --ignore-not-found --grace-period=0 --force`
* **Allocation Workaround**:
  To prevent Terraform from blocking indefinitely while waiting for an IP allocation during service creation, always configure `wait_for_load_balancer = false` on all `kubernetes_service_v1` resources.

## 3. MSAL Insecure Authority Protocols
The Microsoft Authentication Library (MSAL.js) strictly blocks HTTP authority URIs in browsers. When emulating Entra ID locally (e.g., using Floci-AZ), the authority configuration must target a secure endpoint (`https://localhost:4577/...`). Ensure the local emulator has TLS enabled and the emulator's root certificate is trusted (`certutil -user -addstore -f root floci-az.pem`).

## 4. API Server Connection Exhaustion (EOF)
Sending rapid, concurrent, or high-frequency force deletion/patch commands to a local cluster API server can crash or overload `kube-apiserver`, leading to TCP connection drops (`EOF`). Add a brief delay (e.g. `300ms` sleep) between heavy script loops.

## 5. Fail-Early Cluster Provisioning
Automated scripts should verify local cluster health (`kubectl cluster-info` with a short `3s` timeout) at the start of execution. If missing, attempt to start known managers (`minikube start`, `k3d cluster start`, `kind create cluster`) or exit immediately before carrying out resource-heavy Docker builds.

## 6. Service Container Port Mismatch in IaC
When microservices listen on non-standard ports (e.g. `8081` to `8086`), generic Terraform definitions mapping `target_port = 8080` globally will cause liveness/readiness probe failures and `Connection refused` errors.
* **Resolution**: Maintain a dynamic lookup map of service names to container ports in the Terraform locals block, and assign probe ports and service `target_port` dynamically.

## 7. Local LoadBalancer Port Collision
In local Kubernetes environments (e.g., Kind or Docker Desktop), exposing multiple services of type `LoadBalancer` on the same service port (e.g. port `80`) will cause binding collisions on the host machine.
* **Resolution**: Assign unique external ports to each LoadBalancer service (e.g., `80` for the web UI and `8080` for the API gateway) to map them to distinct host ports without conflict.

## 8. Missing Spring Actuator Dependency
Using standard `/actuator/health` health checks in Kubernetes service/deployment readiness and liveness probes requires the `spring-boot-starter-actuator` library. Without it, the application starts successfully but HTTP probes fail with `404 Not Found` errors, placing pods in a permanent `CrashLoopBackOff` restart cycle.
* **Resolution**: Ensure the `spring-boot-starter-actuator` dependency is declared in the root parent `pom.xml` so all microservices inherit it.

## 9. Debian Trixie (Pre-Release) Package and PGP Failures
Debian trixie images (used by default in some LTS base images) lack populated third-party repositories and block PGP v3 signatures (throwing `sqv returned error code (1) Policy rejected packet type`).
* **Resolution**: For Terraform, force the repository to target stable `bookworm` instead of using `$(lsb_release -cs)`. For `kubectl`, download the compiled binary directly via `curl` to bypass apt and PGP checks.

## 10. PowerShell Core Globalization Crash inside Containers
In minimal Linux containers (like Debian trixie/slim), running PowerShell Core (`pwsh`) will fail on startup if the host container lacks `libicu` globalization libraries.
* **Resolution**: Set the environment variable `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true` in the container or the pipeline configuration block to enable globalization-invariant execution.

## 11. Jenkins Local Git Checkout Restrictions
Jenkins Git plugin and Git clients block checkouts and submodule cloning from local `file://` paths by default for security (throwing `fatal: transport 'file' not allowed`).
* **Resolution**: 
  1. Inject `-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true` into the Jenkins container's `JAVA_OPTS` on startup.
  2. Configure Git inside the container to allow local file protocol transports:
     ```bash
     git config --global protocol.file.allow always
     ```

## 12. Container Kubeconfig Host Bridging
When running `kubectl` inside a containerized Jenkins to interact with a local Kubernetes cluster, using a host-copied kubeconfig fails because it targets loopback address `127.0.0.1`.
* **Resolution**: Replace `127.0.0.1` with `host.docker.internal` in the container's kubeconfig (`~/.kube/config`) and add `insecure-skip-tls-verify: true` to bypass certificate SAN restrictions.




