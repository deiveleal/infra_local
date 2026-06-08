resource "kubernetes_deployment" "superset_deploy" {
  metadata {
    name      = "superset"
    namespace = kubernetes_namespace.superset_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "superset"
      }
    }

    template {
      metadata {
        labels = {
          app = "superset"
        }
      }

      spec {
        container {
          image             = "apache/superset:latest"
          name              = "superset"
          image_pull_policy = "IfNotPresent"

          command = ["/bin/bash"]
          args = ["-c", <<-EOT
            superset db upgrade
            superset fab create-admin \
              --username "$SUPERSET_ADMIN_USERNAME" \
              --firstname Admin \
              --lastname Admin \
              --email admin@example.com \
              --password "$SUPERSET_ADMIN_PASSWORD" || true
            superset init
            superset run -h 0.0.0.0 -p 8088 --with-threads --reload --debugger
          EOT
          ]

          port {
            container_port = 8088
            name           = "http"
          }

          env {
            name  = "FLASK_APP"
            value = "superset.app"
          }

          env {
            name  = "SUPERSET_SECRET_KEY"
            value = var.secret_key
          }

          env {
            name  = "SUPERSET_ADMIN_USERNAME"
            value = var.username
          }

          env {
            name  = "SUPERSET_ADMIN_PASSWORD"
            value = var.password
          }

          env {
            name  = "DATABASE_URI"
            value = "postgresql://${var.postgresql_user}:${var.postgresql_password}@${var.postgresql_host}:${var.postgresql_port}/${var.postgresql_db}"
          }

          env {
            name  = "CELERY_BROKER_URL"
            value = "amqp://${var.rabbitmq_user}:${var.rabbitmq_password}@${var.rabbitmq_host}:${var.rabbitmq_port}//"
          }

          env {
            name  = "CELERY_RESULT_BACKEND"
            value = "db+postgresql://${var.postgresql_user}:${var.postgresql_password}@${var.postgresql_host}:${var.postgresql_port}/${var.postgresql_db}"
          }

          env {
            name  = "PYTHONUNBUFFERED"
            value = "1"
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health"
              port   = 8088
              scheme = "HTTP"
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/health"
              port   = 8088
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "superset-data"
            mount_path = "/var/lib/superset"
          }
        }

        volume {
          name = "superset-data"
          host_path {
            path = "/tmp/superset-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.superset_ns
  ]
}
