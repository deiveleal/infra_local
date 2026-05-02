resource "kubernetes_job_v1" "kafka_setup" {
  depends_on = [kubernetes_deployment.kafka_deploy]

  metadata {
    name      = "kafka-setup"
    namespace = kubernetes_namespace.kafka_ns.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "kafka-setup"
        }
      }
      spec {
        container {
          name    = "kafka-cli"
          image   = "apache/kafka:latest"
          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
            KAFKA_BIN=/opt/kafka/bin
            echo "Aguardando Kafka..."
            while ! $KAFKA_BIN/kafka-topics.sh --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 --list > /dev/null 2>&1; do
              sleep 5
              echo "Esperando Kafka broker ficar online..."
            done

            echo "Criando Tópicos..."
            %{for topic in var.topics~}
            $KAFKA_BIN/kafka-topics.sh --create --if-not-exists --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 --partitions 3 --replication-factor 1 --topic ${topic}
            %{endfor~}

            echo "Kafka inicializado!"
            EOT
          ]
          env {
            name  = "NAMESPACE"
            value = var.namespace
          }
        }
        restart_policy = "OnFailure"
      }
    }
    backoff_limit = 5
  }

  lifecycle {
    ignore_changes = [metadata[0].name]
  }
}
