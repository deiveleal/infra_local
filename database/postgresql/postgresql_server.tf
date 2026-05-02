resource "kubernetes_namespace" "postgresql_ns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment_v1" "postgresql_deploy" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.postgresql_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgresql"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgresql"
        }
      }

      spec {
        container {
          image = "postgres:15.17-alpine3.22"
          name  = "postgresql"

          port {
            container_port = 5432
          }

          env {
            name  = "POSTGRES_USER"
            value = var.username
          }

          env {
            name  = "POSTGRES_PASSWORD"
            value = var.password
          }

          env {
            name  = "POSTGRES_DB"
            value = var.database_name
          }

          volume_mount {
            name       = "postgresql-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgresql-data"
          host_path {
            path = "/tmp/postgresql-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}
