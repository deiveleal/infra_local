output "server_minio" {
    value = kubernetes_service.minio_service.metadata[0].name
}

output "server_minio_ns" {
    value = kubernetes_namespace.minio_server_ns.metadata[0].name
}

output "server_minio_deploy" {
    value = kubernetes_deployment.minio_server_deploy.metadata[0].name
}

