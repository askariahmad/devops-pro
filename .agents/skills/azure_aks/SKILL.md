---
name: azure_aks
description: "Instructions, best practices, and troubleshooting for Azure Kubernetes Service (AKS) in the DevOps Pro project."
---

# Skill: Azure Kubernetes Service (AKS)

## Overview
Azure Kubernetes Service (AKS) is a managed Kubernetes service provided by Microsoft Azure, used in the DevOps Pro project to host all microservices (Spring Boot backend + React frontend).

## Capabilities
- **Managed Kubernetes Control Plane**: Azure manages the Kubernetes API server, etcd, and other control plane components.
- **Autoscaling**: Supports cluster autoscaling (add/remove nodes) and horizontal pod autoscaling (add/remove pods).
- **Integrated Azure Services**: Works with ACR (container registry), Azure Monitor (logging/metrics), Key Vault (secrets), and more.
- **Security**: Entra ID integration, RBAC, network policies, and managed identities.

## Deployment in DevOps Pro
The AKS cluster is provisioned via Terraform in `terraform/main.tf`:
- **Resource Group**: `devops-pro-rg`
- **Cluster Name**: `devops-pro-aks`
- **Node Size**: `Standard_DS2_v2` (2 vCPUs, 7 GB RAM)
- **Node Count**: 1 (for dev; use 3+ for production HA)
- **Identity**: SystemAssigned managed identity

## Quick Start (CLI)
1. **Get AKS Credentials**:
   ```bash
   az aks get-credentials --resource-group devops-pro-rg --name devops-pro-aks
   ```
2. **Verify Cluster Access**:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```
3. **Deploy Workloads**:
   The project uses Terraform's `kubernetes` provider to deploy services, but you can also use `kubectl apply` or Helm.

## Key Terraform Configuration
```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.create_azure_infra ? 1 : 0
  name                = "devops-pro-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devopsproaks-${var.environment}"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}
```

## Best Practices for DevOps Pro
1. **Use Managed Identities**: Avoid using service principals with secrets; use AKS's system-assigned managed identity instead.
2. **Enable Cluster Autoscaling**: For production, set `enable_auto_scaling = true` in the node pool.
3. **Use Availability Zones**: For HA, deploy nodes across multiple availability zones (if available in your region).
4. **Integrate with Azure Monitor**: Enable container insights for logging and metrics.
5. **Network Policies**: Implement Kubernetes network policies to restrict pod-to-pod communication.

## Troubleshooting
- **Check Pod Status**: `kubectl get pods -n <namespace>`
- **Check Pod Logs**: `kubectl logs <pod-name> -n <namespace>`
- **Check Events**: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`
- **Check Node Status**: `kubectl describe node <node-name>`
- **AKS Diagnostics**: Use `az aks diagnose` or the Azure portal's "Diagnose and solve problems" blade.

## Local Development with Floci-AZ
For local development, use the Floci-AZ emulator (see `floci_az` skill) to simulate AKS without real Azure costs.
