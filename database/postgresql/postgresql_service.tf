
resource "kubernetes_service_v1" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.postgresql_ns.metadata[0].name
    labels = {
      app = "postgresql"
    }
  }

  spec {
    selector = {
      app = "postgresql"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "NodePort"
  }
}
