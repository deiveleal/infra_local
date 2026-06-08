resource "kubernetes_service_v1" "superset" {
  metadata {
    name      = "superset-service"
    namespace = kubernetes_namespace.superset_ns.metadata[0].name
    labels = {
      app = "superset"
    }
  }

  spec {
    selector = {
      app = "superset"
    }

    port {
      port        = 8088
      target_port = 8088
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [
    kubernetes_namespace.superset_ns
  ]
}
