resource "kubernetes_stateful_set_v1" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = var.namespace
    labels = {
      app = "mongodb"
    }
  }

  spec {
    service_name = kubernetes_service_v1.mongodb.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        container {
          name  = "mongodb"
          image = "mongo:6.0"

          port {
            container_port = 27017
          }

          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = var.mongo_root_username
          }

          env {
            name  = "MONGO_INITDB_ROOT_PASSWORD"
            value = var.mongo_root_password
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }

          volume_mount {
            name       = "init-script"
            mount_path = "/docker-entrypoint-initdb.d"
          }
        }

        volume {
          name = "mongodb-data"
          host_path {
            path = "/tmp/mongodb-data"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "init-script"
          config_map {
            name = kubernetes_config_map_v1.mongodb_init.metadata[0].name
          }
        }
      }
    }
  }
}