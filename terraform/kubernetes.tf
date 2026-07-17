provider "kubernetes" {
  config_path = var.create_cosmos_and_keyvault ? null : "~/.kube/config"

  host                   = var.create_cosmos_and_keyvault ? (var.create_azure_infra ? azurerm_kubernetes_cluster.aks[0].kube_config.0.host : null) : null
  client_certificate     = var.create_cosmos_and_keyvault ? (var.create_azure_infra ? base64decode(azurerm_kubernetes_cluster.aks[0].kube_config.0.client_certificate) : null) : null
  client_key             = var.create_cosmos_and_keyvault ? (var.create_azure_infra ? base64decode(azurerm_kubernetes_cluster.aks[0].kube_config.0.client_key) : null) : null
  cluster_ca_certificate = var.create_cosmos_and_keyvault ? (var.create_azure_infra ? base64decode(azurerm_kubernetes_cluster.aks[0].kube_config.0.cluster_ca_certificate) : null) : null
}

locals {
  services = {
    "dashboard-ui"          = "LoadBalancer"
    "gateway-service"       = "LoadBalancer"
    "config-service"        = "ClusterIP"
    "incident-service"      = "ClusterIP"
    "repo-scanner-service"  = "ClusterIP"
    "log-analyzer-service"  = "ClusterIP"
    "log-collector-service" = "ClusterIP"
    "notification-service"  = "ClusterIP"
  }

  service_ports = {
    "dashboard-ui"          = 80
    "gateway-service"       = 8080
    "log-analyzer-service"  = 8081
    "config-service"        = 8082
    "log-collector-service" = 8083
    "incident-service"      = 8084
    "repo-scanner-service"  = 8085
    "notification-service"  = 8086
  }

  db_names = {
    "dashboard-ui"          = ""
    "gateway-service"       = "devops-pro-auth"
    "config-service"        = "devops_config"
    "incident-service"      = "devops_incidents"
    "repo-scanner-service"  = ""
    "log-analyzer-service"  = ""
    "log-collector-service" = ""
    "notification-service"  = "devops_notifications"
  }

  # Environment variables for Azure production
  env_vars_azure = [
    { name = "SPRING_DATA_MONGODB_URI", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_cosmosdb_account.cosmosdb[0].primary_mongodb_connection_string : "mongodb://host.docker.internal:27017" },
    { name = "SPRING_DATA_REDIS_HOST", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_redis_cache.redis[0].hostname : "host.docker.internal" },
    { name = "SPRING_DATA_REDIS_PORT", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? "6380" : "6379" },
    { name = "SPRING_DATA_REDIS_SSL_ENABLED", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? "true" : "false" },
    { name = "SPRING_DATA_REDIS_PASSWORD", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_redis_cache.redis[0].primary_access_key : "" },
    { name = "KAFKA_BROKERS", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? "aks-kafka-internal:9092" : "host.docker.internal:4577" },
    { name = "SPRING_KAFKA_BOOTSTRAP_SERVERS", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? "aks-kafka-internal:9092" : "host.docker.internal:4577" },
    { name = "AUTH_URL", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? "https://devops-pro-${var.environment}-aks.azure.com" : "http://host.docker.internal:4577" },
    { name = "AZURE_KEY_VAULT_URL", value = (var.create_azure_infra && var.create_cosmos_and_keyvault) ? azurerm_key_vault.keyvault[0].vault_uri : "" },
    { name = "APPLICATION_INSIGHTS_INSTRUMENTATION_KEY", value = var.create_azure_infra ? "your-instrumentation-key-here" : "" }
  ]

  # Environment variables for local development with Floci
  env_vars_local = [
    { name = "SPRING_DATA_MONGODB_URI", value = "mongodb://host.docker.internal:27017" },
    { name = "SPRING_DATA_REDIS_HOST", value = "host.docker.internal" },
    { name = "SPRING_DATA_REDIS_PORT", value = "6379" },
    { name = "SPRING_DATA_REDIS_SSL_ENABLED", value = "false" },
    { name = "SPRING_DATA_REDIS_PASSWORD", value = "" },
    { name = "KAFKA_BROKERS", value = "host.docker.internal:4577" },
    { name = "SPRING_KAFKA_BOOTSTRAP_SERVERS", value = "host.docker.internal:4577" },
    { name = "AUTH_URL", value = "http://host.docker.internal:4577" },
    { name = "AZURE_KEY_VAULT_URL", value = "" },
    { name = "APPLICATION_INSIGHTS_INSTRUMENTATION_KEY", value = "" }
  ]

  service_env_vars = {
    "dashboard-ui" = []
    
    "gateway-service" = [
      { name = "CONFIG_SERVICE_URL", value = "http://config-service" },
      { name = "COLLECTOR_SERVICE_URL", value = "http://log-collector-service" },
      { name = "ANALYZER_SERVICE_URL", value = "http://log-analyzer-service" },
      { name = "SCANNER_SERVICE_URL", value = "http://repo-scanner-service" },
      { name = "INCIDENT_SERVICE_URL", value = "http://incident-service" },
      { name = "NOTIFICATION_SERVICE_URL", value = "http://notification-service" }
    ]

    "config-service" = []

    "incident-service" = [
      { name = "SERVICES_CONFIG_URL", value = "http://config-service/api/v1/config" }
    ]

    "repo-scanner-service" = [
      { name = "SERVICES_CONFIG_URL", value = "http://config-service/api/v1/config" },
      { name = "SERVICES_INCIDENT_URL", value = "http://incident-service/api/v1/incidents" }
    ]

    "log-analyzer-service" = [
      { name = "SERVICES_CONFIG_URL", value = "http://config-service/api/v1/config" },
      { name = "SERVICES_INCIDENT_URL", value = "http://incident-service/api/v1/incidents" }
    ]

    "log-collector-service" = [
      { name = "SERVICES_CONFIG_URL", value = "http://config-service/api/v1/config" },
      { name = "SERVICES_ANALYZER_URL", value = "http://log-analyzer-service/api/v1/analyzer/logs" },
      { name = "SERVICES_MOCK_URL", value = "http://log-collector-service/api/v1/mock/splunk/logs" }
    ]

    "notification-service" = []
  }
}

resource "kubernetes_deployment_v1" "services" {
  for_each = var.create_azure_infra ? local.services : {}

  wait_for_rollout = false

  metadata {
    name = each.key
    labels = {
      app = each.key
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = each.key
      }
    }
    template {
      metadata {
        labels = {
          app = each.key
        }
        annotations = {
          "image/trigger" = lookup(var.service_triggers, each.key, "")
        }
      }
      spec {
        container {
          name  = each.key
          image = "devopspro${var.environment}acr.azurecr.io/${each.key}:latest"

          # Resource limits for production
          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = each.key == "dashboard-ui" ? "/" : "/actuator/health"
              port = local.service_ports[each.key]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = each.key == "dashboard-ui" ? "/" : "/actuator/health"
              port = local.service_ports[each.key]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          # Environment variables
          dynamic "env" {
            for_each = var.create_azure_infra ? local.env_vars_azure : local.env_vars_local
            content {
              name  = env.value.name
              value = env.value.value
            }
          }

          # Service-specific environment variables
          dynamic "env" {
            for_each = local.service_env_vars[each.key]
            content {
              name  = env.value.name
              value = env.value.value
            }
          }

          # Service-specific MongoDB database name
          dynamic "env" {
            for_each = lookup(local.db_names, each.key, "") != "" ? [1] : []
            content {
              name  = "SPRING_DATA_MONGODB_DATABASE"
              value = local.db_names[each.key]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "services" {
  for_each = var.create_azure_infra ? local.services : {}

  wait_for_load_balancer = false

  metadata {
    name = each.key
  }

  spec {
    selector = {
      app = each.key
    }

    type = each.value

    port {
      port        = each.key == "gateway-service" ? 8080 : 80
      target_port = local.service_ports[each.key]
    }
  }
}

variable "service_triggers" {
  description = "Triggers to force redeploying specific services"
  type        = map(string)
  default     = {}
}
