resource "kubernetes_namespace" "superset_ns" {
  metadata {
    name = var.namespace_name
  }
}
