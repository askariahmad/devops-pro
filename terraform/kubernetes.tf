provider "kubernetes" {
  config_path = "~/.kube/config"
}

# dashboard-ui
resource "kubernetes_deployment" "dashboard_ui" {
  metadata { name = "dashboard-ui" }
  spec {
    selector { match_labels = { app = "dashboard-ui" } }
    template {
      metadata { labels = { app = "dashboard-ui" } }
      spec {
        container {
          image = "dashboard-ui:latest"
          name  = "dashboard-ui"
          env { name = "REACT_APP_API_GATEWAY_URL"
                value = "http://gateway-service:8080" }
        }
      }
    }
  }
}
resource "kubernetes_service" "dashboard_ui_svc" {
  metadata { name = "dashboard-ui-service" }
  spec {
    selector = { app = "dashboard-ui" }
    port { port = 80
           target_port = 80 }
    type = "LoadBalancer"
  }
}

# gateway-service
resource "kubernetes_deployment" "gateway_service" {
  metadata { name = "gateway-service" }
  spec {
    selector { match_labels = { app = "gateway-service" } }
    template {
      metadata { labels = { app = "gateway-service" } }
      spec {
        container {
          image = "gateway-service:latest"
          name  = "gateway-service"
          env { name = "AUTH_URL"
                value = "http://localhost:4566" }
        }
      }
    }
  }
}
resource "kubernetes_service" "gateway_service_svc" {
  metadata { name = "gateway-service" }
  spec {
    selector = { app = "gateway-service" }
    port { port = 8080
           target_port = 8080 }
    type = "LoadBalancer"
  }
}

# config-service
resource "kubernetes_deployment" "config_service" {
  metadata { name = "config-service" }
  spec {
    selector { match_labels = { app = "config-service" } }
    template {
      metadata { labels = { app = "config-service" } }
      spec {
        container {
          image = "config-service:latest"
          name  = "config-service"
          env { name = "DB_URL"
                value = "http://localhost:4566" }
        }
      }
    }
  }
}
resource "kubernetes_service" "config_service_svc" {
  metadata { name = "config-service" }
  spec {
    selector = { app = "config-service" }
    port { port = 8080
           target_port = 8080 }
    type = "ClusterIP"
  }
}

# incident-service
resource "kubernetes_deployment" "incident_service" {
  metadata { name = "incident-service" }
  spec {
    selector { match_labels = { app = "incident-service" } }
    template {
      metadata { labels = { app = "incident-service" } }
      spec {
        container {
          image = "incident-service:latest"
          name  = "incident-service"
          env { name = "DB_URL"
                value = "http://localhost:4566" }
          env { name = "KAFKA_URL"
                value = "http://localhost:4566" }
        }
      }
    }
  }
}
resource "kubernetes_service" "incident_service_svc" {
  metadata { name = "incident-service" }
  spec {
    selector = { app = "incident-service" }
    port { port = 8080
           target_port = 8080 }
    type = "ClusterIP"
  }
}

# repo-scanner-service
resource "kubernetes_deployment" "repo_scanner_service" {
  metadata { name = "repo-scanner-service" }
  spec {
    selector { match_labels = { app = "repo-scanner-service" } }
    template {
      metadata { labels = { app = "repo-scanner-service" } }
      spec {
        container {
          image = "repo-scanner-service:latest"
          name  = "repo-scanner-service"
          env { name = "KAFKA_URL"
                value = "http://localhost:4566" }
          env { name = "SPRING_DATA_REDIS_HOST"
                value = aws_elasticache_cluster.redis.cache_nodes[0].address }
        }
      }
    }
  }
}
resource "kubernetes_service" "repo_scanner_service_svc" {
  metadata { name = "repo-scanner-service" }
  spec {
    selector = { app = "repo-scanner-service" }
    port { port = 8080
           target_port = 8080 }
    type = "ClusterIP"
  }
}

# log-analyzer-service
resource "kubernetes_deployment" "log_analyzer_service" {
  metadata { name = "log-analyzer-service" }
  spec {
    selector { match_labels = { app = "log-analyzer-service" } }
    template {
      metadata { labels = { app = "log-analyzer-service" } }
      spec {
        container {
          image = "log-analyzer-service:latest"
          name  = "log-analyzer-service"
          env { name = "KAFKA_URL"
                value = "http://localhost:4566" }
        }
      }
    }
  }
}
resource "kubernetes_service" "log_analyzer_service_svc" {
  metadata { name = "log-analyzer-service" }
  spec {
    selector = { app = "log-analyzer-service" }
    port { port = 8080
           target_port = 8080 }
    type = "ClusterIP"
  }
}

# log-collector-service
resource "kubernetes_deployment" "log_collector_service" {
  metadata { name = "log-collector-service" }
  spec {
    selector { match_labels = { app = "log-collector-service" } }
    template {
      metadata { labels = { app = "log-collector-service" } }
      spec {
        container {
          image = "log-collector-service:latest"
          name  = "log-collector-service"
          env { name = "KAFKA_URL"
                value = "http://localhost:4566" }
        }
      }
    }
  }
}
resource "kubernetes_service" "log_collector_service_svc" {
  metadata { name = "log-collector-service" }
  spec {
    selector = { app = "log-collector-service" }
    port { port = 8080
           target_port = 8080 }
    type = "ClusterIP"
  }
}

# notification-service
resource "kubernetes_deployment" "notification_service" {
  metadata { name = "notification-service" }
  spec {
    selector { match_labels = { app = "notification-service" } }
    template {
      metadata { labels = { app = "notification-service" } }
      spec {
        container {
          image = "notification-service:latest"
          name  = "notification-service"
          env { name = "KAFKA_URL"
                value = "http://localhost:4566" }
        }
      }
    }
  }
}
resource "kubernetes_service" "notification_service_svc" {
  metadata { name = "notification-service" }
  spec {
    selector = { app = "notification-service" }
    port { port = 8080
           target_port = 8080 }
    type = "ClusterIP"
  }
}
