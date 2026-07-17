# Floci.io & Floci-AZ Networking and Emulation Reference

> **Topic**: Floci.io (AWS) and Floci-AZ (Azure) Emulator Networking & Sub-container Provisioning
> **Generated**: 2026-07-15
> **Target Path**: `C:\Users\ahmad\IdeaProjects\devops-pro\.agents\skills\project-knowledge\references\floci-networking.md`

---

## 1. Overview of Floci.io Emulation Architecture

Floci (floci.io) and Floci-AZ are native-compiled, lightweight emulators designed to act as drop-in local cloud replacements for AWS and Azure services. Rather than mocking API contracts abstractly, Floci frequently provisions **real physical Docker containers** for complex compute and resource workloads (such as AWS Lambdas, ECS tasks, EC2 virtual instances, or Azure AKS/K3s control planes and Functions). 

To do this, Floci requires direct access to the host's Docker daemon. This is achieved by mounting the host daemon socket into the emulator container:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

---

## 2. Container-to-Container Networking, Port Mappings, and DNS

### 2.1 Networking Strategy
When Floci spawns child containers (like an EC2 instance or Azure Function pod), these containers must communicate back to the core emulator controller and the host machine. 
* **User-Defined Bridge Network (Mandatory)**: In multi-container environments, relying on Docker's default bridge network is highly discouraged because it does not support automatic container-name DNS resolution. You must create and utilize a custom user-defined network:
  ```bash
  docker network create floci-network
  ```
  Both the Floci emulator container and the developer application microservices must be connected to this network.
* **Firewall Restrictions (Linux Hosts)**: If running on a Linux host with UFW enabled, the default `INPUT DROP` policy blocks packets from the docker bridge to the host. Fix this by explicitly allowing traffic on `docker0`:
  ```bash
  sudo ufw allow in on docker0
  ```

### 2.2 DNS Resolution
* **Embedded DNS Server**: Floci features an internal DNS resolver that intercepts requests for standard cloud domains. Suffixes like `*.localhost.floci.io` and `*.localhost.localstack.cloud` are dynamically mapped to the local Floci container IP.
* **`FLOCI_HOSTNAME` Configuration**: Set `FLOCI_HOSTNAME` to the name of the Floci Docker service (e.g. `FLOCI_HOSTNAME=floci`). This tells spawned containers (like Lambdas) the exact hostname to use when calling back to the Floci parent controller API.
* **`FLOCI_SERVICES_DOCKER_NETWORK`**: Tells Floci which network it should attach its newly spawned containers to, ensuring they are automatically resolvable by Docker's embedded DNS.

### 2.3 Port Mappings
* **Controller Interface**: The primary port (`4566` for AWS, `4577` for Azure) is mapped in your Compose setup so the host machine can query endpoints.
* **Dynamic Guest Mappings**: For emulated virtual instances (like EC2 or AKS VMs), Floci dynamically binds guest services (like SSH port `22`) to a host port range (e.g. `2200-2299`). Run `docker ps` on the host to see the dynamic mappings.
* **Listening Interface**: Application code running inside child containers must bind to `0.0.0.0` (all interfaces) rather than `127.0.0.1` to receive bridged network traffic.

---

## 3. Sub-Container Management in Floci-AZ (AKS, ACR, Redis)

### 3.1 AKS / K3s Emulation
* **Real K3s Mode**: When a Terraform script or Azure CLI command attempts to provision an AKS cluster, `floci-az` spins up a **privileged child Docker container** running **Rancher K3s**.
* **Kubeconfig Retrieval**: Floci-AZ captures the K3s control plane credentials and packages them as a standard AKS `kube_config_raw` response to return to the calling ARM client.
* **K3s Docker Bridge**: K3s manages its own internal pod-network. In order for local workloads to pull images from the local ACR container, you must configure the K3s insecure registries configuration block to accept the non-SSL endpoint of the ACR emulator.

### 3.2 ACR (Azure Container Registry)
* **ACR Registry Service**: ACR is emulated as an HTTP registry registry instance within the emulator namespace. 
* **Interaction**: Since it lacks TLS verification by default, local Docker daemons pushing to it (e.g., `devopsproacr.azurecr.io`) must add the registry address to the host's `insecure-registries` file in `daemon.json`, or access it via HTTP.

### 3.3 Redis (Azure Cache for Redis)
* **Resource Broker**: Requesting an `azurerm_redis_cache` cluster causes the Floci-AZ service to spin up or route requests to an embedded Redis server instance.
* **Accessibility**: Workloads deployed inside the AKS/K3s container can connect directly to the Redis host using standard TCP connections bridged through the shared custom network.

### 3.4 Provisioning States
* **Zero-Wait Optimization**: In real Azure, provisioning resources involves slow state machines (`Creating` $\rightarrow$ `Updating` $\rightarrow$ `Succeeded`). Floci-AZ avoids these latency issues.
* **State Reporting**: The emulator immediately reports the `Succeeded` provisioning state in response payloads once the backing K3s container, ACR registry, or Redis instance has successfully bound to its port.

---

## 4. Key Configuration Flags & Environment Variables

### 4.1 AWS Emulator Variables
* `FLOCI_DOCKER_DOCKER_HOST`: Unix socket or TCP address of Docker daemon (default: `unix:///var/run/docker.sock`).
* `FLOCI_HOSTNAME`: Resolvable hostname of the Floci controller.
* `FLOCI_SERVICES_DOCKER_NETWORK`: Target network for spawned containers.
* `FLOCI_TLS_ENABLED`: Enables HTTP+HTTPS fallback with self-signed certs (`true` / `false`).
* `FLOCI_DNS_EXTRA_SUFFIXES`: Comma-separated list of suffixes to route to the embedded DNS.
* `FLOCI_STORAGE_MODE`: Determines data persistence (`memory`, `persistent`, `hybrid`, `wal`).

### 4.2 Azure Emulator Variables (`FLOCI_AZ_` Prefix)
* `FLOCI_AZ_PORT`: Port exposed by the emulator (default: `4577`).
* `FLOCI_AZ_BASE_URL`: Endpoint returned to SDKs (default: `http://localhost:4577`).
* `FLOCI_AZ_STORAGE_MODE`: Emulation data storage persistence settings.
* `FLOCI_AZ_STORAGE_PATH`: Directory path for persistent files (default: `/app/data`).
* `FLOCI_AZ_TLS_ENABLED`: Enables local HTTPS support for Azure SDK validation.
* `FLOCI_AZ_SERVICES_<SERVICE>_ENABLED`: Enforce activation of specific APIs (e.g. `FLOCI_AZ_SERVICES_AKS_ENABLED=true`).

---

## 5. Multi-Container Compose Integration Blueprint

Below is the recommended pattern to set up local networking when running emulators alongside development services in Docker Compose:

```yaml
version: '3.8'

services:
  floci-az:
    image: floci/floci-az:latest
    container_name: devops-floci-az
    ports:
      - "4577:4577"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - FLOCI_AZ_PORT=4577
      - FLOCI_AZ_STORAGE_MODE=memory
    networks:
      - devops-net

  my-app-service:
    image: my-app:latest
    depends_on:
      - floci-az
    environment:
      # Use the container service name 'floci-az' for internal calls
      - AZURE_BLOB_ENDPOINT=http://devops-floci-az:4577/devstoreaccount1
      - SPRING_DATA_REDIS_HOST=devops-floci-az
    networks:
      - devops-net

networks:
  devops-net:
    name: devops-net
    driver: bridge
```
