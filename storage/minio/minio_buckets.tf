resource "kubernetes_job_v1" "minio_setup_buckets" {
  depends_on = [kubernetes_deployment.minio_server_deploy, kubernetes_service.minio_service]

  metadata {
    name      = "minio-setup-buckets"
    namespace = kubernetes_namespace.minio_server_ns.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "minio-setup"
        }
      }
      spec {
        container {
          name    = "mc"
          image   = "minio/mc:latest"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            echo "Aguardando MinIO iniciar..."
            until mc alias set myminio http://minio-service:9000 $MINIO_USER $MINIO_PASSWORD 2>/dev/null; do
              sleep 2
              echo "Tentando conectar ao MinIO..."
            done
            echo "MinIO conectado! Criando buckets..."
            %{ for bucket in var.buckets_names ~}
            mc mb myminio/${bucket} || echo "Bucket ${bucket} já existe ou erro ao criar"
            %{ endfor ~}
            echo "Setup de buckets concluído!"
            EOT
          ]
          env {
            name  = "MINIO_USER"
            value = var.basic_username
          }
          env {
            name  = "MINIO_PASSWORD"
            value = var.basic_password
          }
        }
        restart_policy = "OnFailure"
      }
    }
  }

  lifecycle {
    ignore_changes = [metadata[0].name]
  }
}
