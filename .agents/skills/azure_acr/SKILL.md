---
name: azure_acr
description: "Instructions, best practices, and troubleshooting for Azure Container Registry (ACR) in the DevOps Pro project."
---

# Skill: Azure Container Registry (ACR)

## Overview
Azure Container Registry (ACR) is a managed Docker container registry service provided by Microsoft Azure, used in the DevOps Pro project to store all Docker images for microservices and the frontend.

## Capabilities
- **Private Registry**: Store container images privately (not public on Docker Hub).
- **Geo-replication**: Replicate images across multiple Azure regions for low-latency pulls.
- **Security**: Entra ID authentication, image signing, vulnerability scanning (via Microsoft Defender for Containers).
- **Webhooks**: Trigger CI/CD pipelines on image pushes.

## Deployment in DevOps Pro
The ACR is provisioned via Terraform in `terraform/main.tf`:
- **Resource Group**: `devops-pro-rg`
- **Registry Name**: `devopsproacr`
- **SKU**: Standard (supports geo-replication; Basic is for dev/test)
- **Admin User**: Enabled (for simplicity in dev; use managed identities for production)

## Quick Start (Portal)
1. **Create an ACR instance**:
   - **Note about Azure region policies**: Your subscription may have an Azure Policy that restricts which regions you can deploy to! To find allowed regions, go to the Azure portal → search for "Policy" → check "Assignments"!
   - Search for "Container registries" in the Azure Portal → click **Create**
   - **Basics Tab**:
     - **Subscription**: Select your subscription
     - **Resource group**: Select or create `devops-pro-rg`
     - **Registry name**: Enter a unique name (e.g., `devopsproacr`; 5-50 chars, lowercase letters/numbers only)
     - **Location**: Choose an **allowed region** (check your Azure Policy first)
     - **Pricing plan**: Basic (dev/test), Standard (production), Premium (advanced features like geo-replication, availability zones)
     - **Domain name label scope**: Choose **No reuse** (recommended—your registry's DNS name is globally unique and can't be used by anyone else)
     - **Availability zones** (only if Premium SKU is selected): Enable to make your registry zone-redundant (available in regions that support AZs)
   - **Encryption Tab**: Leave as default (Microsoft-managed keys)
   - **Networking Tab**: Leave as default (Public access)
   - **Advanced Tab**:
     - **Admin user**: Enable (for `az acr login` without managed identity; for production, use managed identities instead)
     - **Role assignment permissions mode**: Choose either:
       - **RBAC Registry Permissions** (default/recommended): Only Azure RBAC applies to the entire registry (simpler, good for basic deployments)
       - **RBAC Registry + ABAC Repository Permissions**: Use both Azure RBAC and ABAC for granular repository-level permissions (good for complex scenarios with multiple teams/repos)
   - **Tags Tab**: (Optional) Add tags to organize your resources (key-value pairs)
     - Example tags:
       - `Environment`: `Production`
       - `Project`: `DevOps-Pro`
       - `Department`: `Engineering`
   - Click **Review + create** → **Create**

## Quick Start (CLI)
1. **Create an ACR instance**:
   - **Note about Azure region policies**: Your subscription may have an Azure Policy that restricts which regions you can deploy to! To find allowed regions, go to the Azure portal → search for "Policy" → check "Assignments"!
   ```bash
   az acr create --resource-group devops-pro-rg \
       --name devopsproacr \
       --sku Basic \
       --admin-enabled true \
       --location <allowed-region>  # Replace with an allowed region!
   ```
2. **Login to ACR**:
   ```bash
   az acr login --name devopsproacr
   ```
3. **Tag an Image**:
   ```bash
   docker tag my-image:latest devopsproacr.azurecr.io/my-image:latest
   ```
4. **Push an Image**:
   ```bash
   docker push devopsproacr.azurecr.io/my-image:latest
   ```
5. **List Repositories**:
   ```bash
   az acr repository list --name devopsproacr --output table
   ```

## Key Terraform Configuration
```hcl
resource "azurerm_container_registry" "acr" {
  name                = "devopsproacr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location  # Make sure this is an allowed region!
  sku                 = "Standard"
  admin_enabled       = true
}
```

## Best Practices for DevOps Pro
1. **Use Managed Identities**: For AKS to pull images from ACR without credentials, use AKS's managed identity with `AcrPull` role.
2. **Enable Geo-replication**: For production, replicate the registry to regions where your AKS clusters are deployed.
3. **Scan for Vulnerabilities**: Enable Microsoft Defender for Containers to scan images for vulnerabilities.
4. **Image Tagging**: Use semantic versioning (e.g., `1.0.0`, `1.0.1`) or commit hashes instead of `latest` for production.
5. **Purge Old Images**: Set up a retention policy to delete old, unused images to save costs.

## Troubleshooting
- **Login Issues**: Make sure you're logged into the correct Azure tenant and have `AcrPush`/`AcrPull` permissions.
- **Image Pull Failures in AKS**: Verify that the AKS managed identity has the `AcrPull` role on the ACR.
- **Slow Image Pushes/Pulls**: Use the same Azure region for ACR and AKS, or enable geo-replication.

## Local Development with Floci-AZ
For local development, use the Floci-AZ emulator (see `floci_az` skill) to simulate ACR without real Azure costs.
