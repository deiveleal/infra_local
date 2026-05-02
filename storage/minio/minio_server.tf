resource "kubernetes_namespace" "minio_server_ns" {
  metadata {
    name = "minio-server-ns"
  }
}

resource "kubernetes_deployment" "minio_server_deploy" {
  metadata {
    name      = "minio-server-deploy"
    namespace = kubernetes_namespace.minio_server_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        App = "Minio"
      }
    }

    template {
      metadata {
        labels = {
          App = "Minio"
        }
      }

      spec {
        container {
          image             = "minio/minio:latest"
          name              = "minio"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "MINIO_ROOT_USER"
            value = var.basic_username
          }

          env {
            name  = "MINIO_ROOT_PASSWORD"
            value = var.basic_password
          }

          port {
            container_port = 9000
            name           = "api"
          }

          port {
            container_port = 9001
            name           = "console"
          }

          args = ["server", "/data", "--console-address", ":9001"]

          volume_mount {
            name       = "minio-storage"
            mount_path = "/data"
          }

          resources {
            limits = {
              cpu    = "1000m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/minio/health/live"
              port   = 9000
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/minio/health/ready"
              port   = 9000
              scheme = "HTTP"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }
        }

        volume {
          name = "minio-storage"
          host_path {
            path = "/tmp/minio-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "minio_service" {
  metadata {
    name      = "minio-service"
    namespace = kubernetes_namespace.minio_server_ns.metadata[0].name
  }

  spec {
    selector = {
      App = "Minio"
    }

    port {
      name        = "minio-api-port"
      port        = 9000
      target_port = 9000
      node_port   = 30900
    }

    port {
      name        = "minio-console-port"
      port        = 9001
      target_port = 9001
      node_port   = 30901
    }

    type = "NodePort"
  }
}