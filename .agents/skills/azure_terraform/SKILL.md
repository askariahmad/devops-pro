---
name: azure_terraform
description: "Instructions, best practices, and troubleshooting for using Terraform with Azure (azurerm provider) in the DevOps Pro project."
---

# Skill: Terraform with Azure (azurerm provider)

## Overview
Terraform is an open-source infrastructure as code (IaC) tool used in the DevOps Pro project to provision all Azure resources (AKS, ACR, Redis Cache, etc.). The Azure provider (`hashicorp/azurerm`) is used to interact with Azure Resource Manager (ARM).

## Key Files in DevOps Pro
- `terraform/main.tf`: Defines core Azure resources (resource group, AKS, ACR, Redis Cache)
- `terraform/kubernetes.tf`: Defines Kubernetes resources deployed to AKS

## Quick Start
1. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```
2. **Format and Validate Configuration**:
   ```bash
   terraform fmt
   terraform validate
   ```
3. **Plan Changes**:
   ```bash
   terraform plan -out=plan.out
   ```
4. **Apply Changes**:
   ```bash
   terraform apply "plan.out"
   ```
5. **Destroy Resources (when done)**:
   ```bash
   terraform destroy
   ```

## Terraform Configuration (main.tf)
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  metadata_host   = var.azure_metadata_host # For Floci-AZ emulator
}
```

## Best Practices for DevOps Pro
1. **Use a Remote Backend**: For production, use Azure Blob Storage as a remote backend to store Terraform state (don't store it locally or in git).
2. **Variables**: Use variables (in `variables.tf` or `terraform.tfvars`) for values that change (like region, SKUs, etc.).
3. **Outputs**: Define outputs for important values (like AKS kubeconfig, Redis connection string) so you don't have to look them up in the portal.
4. **Modules**: As your infrastructure grows, organize it into Terraform modules for reusability (e.g., a "networking" module, an "aks" module).
5. **Plan Before Apply**: Always run `terraform plan` and review the changes before running `terraform apply`.
6. **Keep Secrets Out of Git**: Use environment variables, Azure Key Vault, or a secrets manager for sensitive data (never commit client secrets, passwords, etc.).

## Local Development with Floci-AZ
For local development, use the Floci-AZ emulator (see `floci_az` skill):
- Set `var.azure_metadata_host` to `http://localhost:4577`
- Set `var.create_azure_infra` to `false` if needed
- The other Terraform variables can be placeholder UUIDs for the emulator

## Troubleshooting
- **Authentication Errors**: Make sure your Azure credentials (tenant ID, subscription ID, client ID, client secret) are correct and have the right permissions.
- **State Issues**: If your Terraform state gets out of sync, you can use `terraform import` or `terraform state rm` to fix it.
- **Resource Provisioning Failures**: Check the Terraform logs and Azure portal's activity log for errors.
- **Floci-AZ Emulator Issues**: If the emulator isn't working, restart it (docker rm -f floci-az, then docker run again) and make sure port 4577 isn't in use.

## Gitignore
Make sure you have these in your `.gitignore` (already in the project):
```
terraform/.terraform
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/terraform.tfvars
terraform/*override.tf
```
