resource "kubernetes_namespace" "rabbitmq_ns" {
  metadata {
    name = "rabbitmq-ns"
  }
}

resource "kubernetes_secret" "rabbitmq_auth" {
  metadata {
    name      = "rabbitmq-auth"
    namespace = kubernetes_namespace.rabbitmq_ns.metadata[0].name
  }

  data = {
    RABBITMQ_DEFAULT_USER = var.username
    RABBITMQ_DEFAULT_PASS = var.password
  }
}

resource "kubernetes_deployment" "rabbitmq_deploy" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        container {
          # Usamos a imagem 'management' para ter a interface web na porta 15672
          image = "rabbitmq:4.0.9-management-alpine"
          name  = "rabbitmq"

          env_from {
            secret_ref {
              name = kubernetes_secret.rabbitmq_auth.metadata[0].name
            }
          }

          port {
            name           = "amqp"
            container_port = 5672
          }

          port {
            name           = "management"
            container_port = 15672
          }

          volume_mount {
            name       = "rabbitmq-storage"
            mount_path = "/var/lib/rabbitmq"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 10
          }

          readiness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "check_running"]
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }
        volume {
          name = "rabbitmq-storage"
          host_path {
            path = "/tmp/rabbitmq-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq_service" {
  metadata {
    name      = "rabbitmq-service"
    namespace = kubernetes_namespace.rabbitmq_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "rabbitmq"
    }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
      node_port   = 30672
    }

    port {
      name        = "management"
      port        = 15672
      target_port = 15672
      node_port   = 31672
    }

    type = "NodePort"
  }
}
