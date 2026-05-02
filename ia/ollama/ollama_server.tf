resource "kubernetes_namespace" "ollama_ns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "ollama_deploy" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.ollama_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "ollama"
      }
    }

    template {
      metadata {
        labels = {
          app = "ollama"
        }
      }

      spec {
        container {
          image             = "ollama/ollama:latest"
          name              = "ollama"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 11434
            name           = "api"
          }

          volume_mount {
            name       = "ollama-data"
            mount_path = "/root/.ollama"
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "8Gi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/"
              port   = 11434
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/"
              port   = 11434
              scheme = "HTTP"
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        volume {
          name = "ollama-data"
          host_path {
            path = "/tmp/ollama-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ollama_service" {
  metadata {
    name      = "ollama-service"
    namespace = kubernetes_namespace.ollama_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "ollama"
    }

    port {
      name        = "api"
      port        = 11434
      target_port = 11434
      node_port   = 31434
    }

    type = "NodePort"
  }
}

resource "kubernetes_job_v1" "ollama_pull_models" {
  count      = length(var.models) > 0 ? 1 : 0
  depends_on = [kubernetes_deployment.ollama_deploy]

  metadata {
    name      = "ollama-pull-models"
    namespace = kubernetes_namespace.ollama_ns.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "ollama-setup"
        }
      }
      spec {
        container {
          name    = "ollama-cli"
          image   = "ollama/ollama:latest"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            echo "Aguardando Ollama iniciar..."
            until OLLAMA_HOST=http://ollama-service:11434 ollama list > /dev/null 2>&1; do
              sleep 5
              echo "Esperando Ollama..."
            done
            %{for model in var.models~}
            echo "Baixando modelo: ${model}"
            OLLAMA_HOST=http://ollama-service:11434 ollama pull ${model}
            %{endfor~}
            echo "Modelos prontos!"
            EOT
          ]
        }
        restart_policy = "OnFailure"
      }
    }
    backoff_limit = 2
  }

  timeouts {
    create = "60m"
  }

  lifecycle {
    ignore_changes = [metadata[0].name]
  }
}
