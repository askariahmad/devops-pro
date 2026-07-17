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
  tenant_id                  = "00000000-0000-0000-0000-000000000000"
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  client_id                  = "00000000-0000-0000-0000-000000000000"
  client_secret              = "00000000-0000-0000-0000-000000000000"
  metadata_host              = var.azure_metadata_host
}

variable "azure_metadata_host" {
  description = "The metadata host for the AzureRM provider (set to localhost:4577 for Floci-AZ)."
  type        = string
  default     = null
}

variable "create_azure_infra" {
  description = "Set to true only when you want Terraform to create real Azure resources. Local Floci runs default to this disabled to avoid unsupported AKS/Redis provisioning."
  type        = bool
  default     = false
}

variable "create_cosmos_and_keyvault" {
  description = "Enable provisioning of Cosmos DB and Key Vault. Set to false for local Floci-AZ runs due to emulator/DNS limitations."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  default     = "prod"
}

resource "azurerm_resource_group" "rg" {
  name     = "devops-pro-${var.environment}-rg"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  count = var.create_azure_infra ? 1 : 0

  name                = "devops-pro-${var.environment}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devopsproaks-${var.environment}"

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_DS2_v2"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 10
  }

  # Enable AKS features for production
  dynamic "oms_agent" {
    for_each = var.create_cosmos_and_keyvault ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace[0].id
    }
  }

  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    tenant_id = "00000000-0000-0000-0000-000000000000"
    managed   = true
  }

  # Enable Azure Policy add-on
  azure_policy_enabled = var.create_cosmos_and_keyvault

  # Enable private networking
  private_cluster_enabled = var.create_cosmos_and_keyvault

  # Configure service mesh (optional)
  dynamic "service_mesh_profile" {
    for_each = var.create_cosmos_and_keyvault ? [1] : []
    content {
      mode = "Istio"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Configure network policies
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = "10.0.0.10"
    service_cidr      = "10.0.0.0/16"
  }
}

# Configure node pools for different workloads
resource "azurerm_kubernetes_cluster_node_pool" "system" {
  count                 = var.create_cosmos_and_keyvault ? 1 : 0
  name                  = "system"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  node_count            = 2
  vm_size               = "Standard_DS2_v2"
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 5
  mode                  = "System"
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  count                 = var.create_cosmos_and_keyvault ? 1 : 0
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  node_count            = 2
  vm_size               = "Standard_DS3_v2"
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 10
  mode                  = "User"
  node_labels = {
    workload = "production"
  }
}

# Configure Azure AD integration role assignment
resource "azurerm_role_assignment" "aks_user" {
  count              = var.create_cosmos_and_keyvault ? 1 : 0
  scope              = var.create_cosmos_and_keyvault ? azurerm_kubernetes_cluster.aks[0].id : azurerm_resource_group.rg.id
  role_definition_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/4abbcc35-e782-4f38-869f-4c096d38d157"
  principal_id       = "00000000-0000-0000-0000-000000000000"
}

resource "azurerm_log_analytics_workspace" "workspace" {
  count = var.create_azure_infra ? 1 : 0

  name                = "devops-pro-${var.environment}-workspace"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_registry" "acr" {
  name                = "devopspro${var.environment}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true
}

resource "azurerm_key_vault" "keyvault" {
  count = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? 1 : 0

  name                = "devops-pro-${var.environment}-kv"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = "00000000-0000-0000-0000-000000000000"
  sku_name            = "standard"

  access_policy {
    tenant_id = "00000000-0000-0000-0000-000000000000"
    object_id = "00000000-0000-0000-0000-000000000000"
    key_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }
}

resource "azurerm_key_vault_access_policy" "aks_policy" {
  count        = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? 1 : 0
  key_vault_id = azurerm_key_vault.keyvault[0].id
  tenant_id    = azurerm_kubernetes_cluster.aks[0].identity[0].tenant_id
  object_id    = azurerm_kubernetes_cluster.aks[0].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  count = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? 1 : 0

  name                = "devops-pro-${var.environment}-cosmosdb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  capabilities {
    name = "EnableMongo"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  # Enable multiple write locations for high availability
  multiple_write_locations_enabled = true
}

resource "azurerm_redis_cache" "redis" {
  count = var.create_cosmos_and_keyvault ? 1 : 0

  name                = "devops-pro-${var.environment}-redis"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  non_ssl_port_enabled = false
  minimum_tls_version = "1.2"
}

output "kubeconfig" {
  value     = var.create_azure_infra ? azurerm_kubernetes_cluster.aks[0].kube_config_raw : null
  sensitive = true
}

output "redis_primary_connection_string" {
  value     = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_redis_cache.redis[0].primary_connection_string : null
  sensitive = true
}

output "cosmosdb_connection_string" {
  value     = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_cosmosdb_account.cosmosdb[0].primary_key : null
  sensitive = true
}

output "key_vault_url" {
  value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_key_vault.keyvault[0].vault_uri : null
}
