# Floci-AZ AKS Emulation Troubleshooting & Diagnostics Reference

> **Topic**: Diagnosing and Tuning Emulated AKS Cluster Initialization (K3s-backed) in Floci-AZ
> **Generated**: 2026-07-15
> **Target Path**: `C:\Users\ahmad\IdeaProjects\devops-pro\.agents\skills\project-knowledge\references\floci-aks-troubleshooting.md`

---

## 1. Host Resource Constraints & Allocation

When running `floci-az` in **Real K3s Mode** (the default mode when provisioning AKS), the emulator spawns a nested, privileged `rancher/k3s:latest` container to serve as the Kubernetes control plane. K3s has structural minimums that are easily bottlenecked by local virtualization layers (WSL2 / Docker Desktop):

### 1.1 Minimum & Recommended Resources
* **K3s Control Plane Baseline**: Requires a minimum of **1.5 GB to 1.6 GB of RAM** and **1 CPU Core** just to start the API server, database (SQLite/etcd), scheduler, and controller manager in an idle state.
* **Devops Pro Workload Overhead**: Running the 8 dashboard microservices + frontend containers on top of K3s adds another **4 GB to 6 GB of RAM** and **2 cores**.
* **WSL2 / Docker Desktop Configuration**:
  * **Minimum Allocation**: 2 Cores, 6 GB RAM.
  * **Recommended Allocation**: 4 Cores, 8–12 GB RAM.
  * **Virtual Disk I/O**: K3s is highly write-intensive (compiling certificates and committing SQLite database writes). If your Docker virtual disk (`ext4.vhdx` on WSL2) is hosted on a traditional Hard Disk Drive (HDD) or a slow network-mount, etcd/SQLite commit latency will cause K3s to timeout. It must run on an **SSD**.
  * **WSL2 Resource Cap**: Ensure you have a `.wslconfig` file in your Windows user directory (`C:\Users\<User>\.wslconfig`) allocating sufficient resources to prevent the VM from starving:
    ```ini
    [wsl2]
    memory=12GB
    processors=4
    ```

---

## 2. Diagnostics: Checking the Nested K3s Container

If the AKS cluster status is stuck in `Creating` for over 5 minutes, you can query the nested container directly.

### 2.1 Locating the Sub-Container
Floci-AZ creates a separate container named using the pattern `floci-az-aks-{instanceId}`.
1. Run `docker ps -a` on the host to locate the exact container name:
   ```bash
   docker ps --filter "name=floci-az-aks"
   ```

### 2.2 CLI Diagnostics to Run Against the Nested Container
Since it is a standard Linux/K3s container, you can exec commands directly inside it to check the control plane status:

1. **Check Node Status**:
   ```bash
   docker exec -it floci-az-aks-<instanceId> kubectl get nodes
   ```
2. **Check System Pods (DNS, Storage, ServiceLB)**:
   ```bash
   docker exec -it floci-az-aks-<instanceId> kubectl get pods -n kube-system
   ```
3. **Inspect the K3s Logs**:
   Read the direct console logs of K3s inside the sub-container:
   ```bash
   docker logs floci-az-aks-<instanceId>
   ```

### 2.3 Diagnostic Log Patterns to Collect & Watch For
When examining the logs of the `floci-az-aks-` sub-container, look for these critical patterns:

| Log Pattern / Error Message | Meaning | Mitigation |
|---|---|---|
| `"x509: certificate has expired or is not yet valid"` | **Clock Skew Bug**: The host system's clock is out of sync with WSL2/Docker virtual clock, causing generated TLS certs to be evaluated as invalid. | Restart WSL2 (`wsl --shutdown`) or force host time synchronization (`hwclock -s` / NTP check). |
| `"Level=fatal error=\"cgroups: cannot find cgroup mount destination...\""` | **Cgroup Mounting Failure**: The Docker environment is restricting privileged operations or cgroups v2 mount structures. | Run Docker in privileged mode or ensure `systemd` is enabled in your WSL distribution. |
| `"Failed to create database connection"` / `"database is locked"` | **I/O Bottleneck / Timeout**: Disk writing speed is too slow to commit database entries, triggering etcd startup timeouts. | Move Docker data files to an SSD. |
| `"OOMKilled"` / `"Exit code 137"` | **Out-of-Memory**: The nested container exceeded host memory allocations and was terminated by the Linux kernel. | Increase Docker memory limits in Docker Desktop or WSL2 configuration. |

---

## 3. Floci-AZ Environment Variables & Configuration Tuning

Floci-AZ supports specific configuration flags to tune AKS cluster creation and timeout behaviors:

### 3.1 Mocked AKS Mode (Immediate Startup)
If the project's local integration test suite does not require deploying physical pods inside the nested K3s cluster (e.g., you only need to verify that Terraform compiles, AKS exists, and resource references resolve), you can enable **Mocked Mode**:
* **Flag**: `FLOCI_AZ_SERVICES_AKS_MOCKED=true`
* **Behavior**: Bypasses K3s Docker container spawning entirely. The provisioning state transitions from `Creating` to `Succeeded` in milliseconds, generating a mock kubeconfig. This completely resolves host resource bottlenecks.

### 3.2 Key Tuning Environment Variables
Inject these flags into the environment of the main `floci-az` container to adjust behavior:

| Environment Variable | Recommended Value | Purpose |
|---|---|---|
| **`FLOCI_AZ_SERVICES_AKS_MOCKED`** | `true` (or `false` for full deployments) | Set to `true` to disable actual K3s container startup and speed up testing. |
| **`FLOCI_AZ_TLS_ENABLED`** | `false` | Disabling TLS locally skips generating cert files, which reduces initialization overhead. |
| **`FLOCI_AZ_SERVICES_K3S_TIMEOUT`** | `600` (Seconds) | Adjusts the timeout threshold for the background readiness poller before giving up. |
| **`FLOCI_AZ_STORAGE_MODE`** | `memory` | Ensures that metadata state is kept in-RAM rather than writing constantly to local disks, saving I/O. |

---

## 4. Summary Action Plan for the Team

1. **Verify Resources**: Verify Docker Desktop is allocated at least 8 GB of RAM and 4 CPUs.
2. **Apply WSL Config**: Create/Update `C:\Users\<User>\.wslconfig` with resource overrides.
3. **Inspect Sub-Container logs**:
   ```bash
   docker logs $(docker ps -aq --filter name=floci-az-aks)
   ```
4. **Fallback to Mock Mode**: If resource allocation cannot be increased on developer machines, set `FLOCI_AZ_SERVICES_AKS_MOCKED=true` in `docker-compose.yml` environment settings.
