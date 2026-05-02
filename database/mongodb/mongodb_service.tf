resource "kubernetes_service_v1" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = var.namespace
    labels = {
      app = "mongodb"
    }
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
    }

    type = "ClusterIP"
  }
}

