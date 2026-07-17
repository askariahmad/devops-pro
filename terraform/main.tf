terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  tenant_id                  = var.azure_tenant_id
  subscription_id            = var.azure_subscription_id
  client_id                  = var.azure_client_id
  client_secret              = var.azure_client_secret
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
  location = var.azure_region
}

resource "azurerm_kubernetes_cluster" "aks" {
  count = var.create_azure_infra ? 1 : 0

  name                = "devops-pro-${var.environment}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devopsproaks-${var.environment}"

  default_node_pool {
    name                 = "default"
    node_count           = 1
    vm_size              = "Standard_D2s_v3"
    auto_scaling_enabled = false
  }

  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    tenant_id = "00000000-0000-0000-0000-000000000000"
  }

  # Enable Azure Policy add-on
  azure_policy_enabled = var.create_cosmos_and_keyvault

  # Enable private networking
  private_cluster_enabled = false



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
  count                 = 0
  name                  = "system"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  node_count            = 2
  vm_size               = "Standard_D2s_v3"
  auto_scaling_enabled   = true
  min_count             = 2
  max_count             = 5
  mode                  = "System"
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  count                 = 0
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  node_count            = 2
  vm_size               = "Standard_D2s_v3"
  auto_scaling_enabled   = true
  min_count             = 2
  max_count             = 10
  mode                  = "User"
  node_labels = {
    workload = "production"
  }
}

# Configure Azure AD integration role assignment
resource "azurerm_role_assignment" "aks_user" {
  count              = 0
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

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "keyvault" {
  count = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? 1 : 0

  name                = "devops-pro-${var.environment}-kv"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
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

resource "azurerm_managed_redis" "redis" {
  count               = var.create_cosmos_and_keyvault ? 1 : 0
  name                = "devops-pro-${var.environment}-redis"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Balanced_B3"

  default_database {
    client_protocol                    = "Encrypted"
    clustering_policy                  = "OSSCluster"
    eviction_policy                    = "VolatileLRU"
    access_keys_authentication_enabled = true
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.create_azure_infra ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
}

output "kubeconfig" {
  value     = var.create_azure_infra ? azurerm_kubernetes_cluster.aks[0].kube_config_raw : null
  sensitive = true
}



output "redis_hostname" {
  value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_managed_redis.redis[0].hostname : null
}

output "redis_ssl_port" {
  value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_managed_redis.redis[0].default_database[0].port : null
}

output "redis_primary_access_key" {
  value     = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_managed_redis.redis[0].default_database[0].primary_access_key : null
  sensitive = true
}

output "cosmosdb_connection_string" {
  value     = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_cosmosdb_account.cosmosdb[0].primary_key : null
  sensitive = true
}

output "key_vault_url" {
  value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_key_vault.keyvault[0].vault_uri : null
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
