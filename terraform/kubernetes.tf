provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

locals {
  services = {
    "dashboard-ui"         = "LoadBalancer"
    "gateway-service"      = "LoadBalancer"
    "config-service"       = "ClusterIP"
    "incident-service"     = "ClusterIP"
    "repo-scanner-service" = "ClusterIP"
    "log-analyzer-service" = "ClusterIP"
    "log-collector-service"= "ClusterIP"
    "notification-service" = "ClusterIP"
  }

  env_vars = [
    { name = "DB_HOST",       value = "http://localhost:4577" },
    { name = "KAFKA_BROKERS", value = "http://localhost:4577" },
    { name = "AUTH_URL",      value = "http://localhost:4577" }
  ]
}

resource "kubernetes_deployment" "services" {
  for_each = local.services

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
      }
      spec {
        container {
          name  = each.key
          image = "devopsproacr.azurecr.io/{each.key}:latest"
          
          dynamic "env" {
            for_each = local.env_vars
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "services" {
  for_each = local.services

  metadata {
    name = each.key
  }

  spec {
    selector = {
      app = each.key
    }
    
    type = each.value

    port {
      port        = 80
      target_port = 8080
    }
  }
}
