resource "kubernetes_namespace" "mongodb_ns" {
  metadata {
    name = var.namespace
  }
}