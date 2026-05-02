resource "kubernetes_namespace" "kafka_ns" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "kafka_deploy" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace.kafka_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        container {
          name              = "kafka"
          image             = "apache/kafka:latest"
          image_pull_policy = "IfNotPresent"

          # KRaft combined mode — broker + controller in one pod
          env {
            name  = "KAFKA_NODE_ID"
            value = "1"
          }
          env {
            name  = "KAFKA_PROCESS_ROLES"
            value = "broker,controller"
          }

          # CLIENT  → pods inside the cluster (init job, apps) via svc:9092
          # EXTERNAL → kubectl port-forward, advertises localhost:9092 on pod port 9094
          # CONTROLLER → internal KRaft consensus
          env {
            name  = "KAFKA_LISTENERS"
            value = "CLIENT://0.0.0.0:9092,EXTERNAL://0.0.0.0:9094,CONTROLLER://0.0.0.0:9093"
          }
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "CLIENT://kafka.${var.namespace}.svc.cluster.local:9092,EXTERNAL://localhost:9092"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "CONTROLLER:PLAINTEXT,CLIENT:PLAINTEXT,EXTERNAL:PLAINTEXT"
          }
          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "CLIENT"
          }
          env {
            name  = "KAFKA_CONTROLLER_LISTENER_NAMES"
            value = "CONTROLLER"
          }
          env {
            name  = "KAFKA_CONTROLLER_QUORUM_VOTERS"
            value = "1@localhost:9093"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
            value = "1"
          }
          env {
            name  = "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR"
            value = "1"
          }
          env {
            name  = "KAFKA_LOG_DIRS"
            value = "/tmp/kraft-combined-logs"
          }

          port {
            container_port = 9092
            name           = "client"
          }
          port {
            container_port = 9094
            name           = "external"
          }
          port {
            container_port = 9093
            name           = "controller"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            failure_threshold     = 3
          }

          readiness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            failure_threshold     = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kafka_service" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace.kafka_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "kafka"
    }

    # Internal access for pods and init job
    port {
      name        = "client"
      port        = 9092
      target_port = 9092
    }

    # Port-forward maps localhost:9092 → pod:9094 (EXTERNAL listener)
    port {
      name        = "external"
      port        = 9094
      target_port = 9094
    }

    type = "ClusterIP"
  }
}
