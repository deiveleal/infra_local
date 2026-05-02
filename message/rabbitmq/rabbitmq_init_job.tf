resource "kubernetes_job_v1" "rabbitmq_setup" {
  depends_on = [kubernetes_deployment.rabbitmq_deploy, kubernetes_service.rabbitmq_service]

  metadata {
    name      = "rabbitmq-setup"
    namespace = kubernetes_namespace.rabbitmq_ns.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "rabbitmq-setup"
        }
      }
      spec {
        container {
          name    = "curl"
          image   = "curlimages/curl:8.10.1"
          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
            echo "Aguardando RabbitMQ iniciar..."
            until curl -s "http://rabbitmq-service:15672/api/health/checks/alarms" -u "$RMQ_USER:$RMQ_PASS"; do
              sleep 3
            done

            echo "RabbitMQ pronto. Configurando VHost, Permissoes, Filas e Exchanges..."
            
            # Create VHost
            curl -X PUT -s "http://rabbitmq-service:15672/api/vhosts/eda-vhost" \
                 -u "$RMQ_USER:$RMQ_PASS" \
                 -H "Content-Type: application/json" \
                 -d '{"description":"EDA Vhost", "tags":"tracing"}'

            # Set Permissions
            curl -X PUT -s "http://rabbitmq-service:15672/api/permissions/eda-vhost/$RMQ_USER" \
                 -u "$RMQ_USER:$RMQ_PASS" \
                 -H "Content-Type: application/json" \
                 -d '{"configure":".*", "write":".*", "read":".*"}'

            # Set Topic Permissions
            curl -X PUT -s "http://rabbitmq-service:15672/api/topic-permissions/eda-vhost/$RMQ_USER" \
                 -u "$RMQ_USER:$RMQ_PASS" \
                 -H "Content-Type: application/json" \
                 -d '{"exchange":"amq.topic", "write":".*", "read":".*"}'

            # Create Fanout Exchange
            curl -X PUT -s "http://rabbitmq-service:15672/api/exchanges/eda-vhost/eda-exchange" \
                 -u "$RMQ_USER:$RMQ_PASS" \
                 -H "Content-Type: application/json" \
                 -d '{"type":"fanout","auto_delete":true,"durable":false}'

            %{ for queue in var.topic_name ~}
            # Create Queues
            curl -X PUT -s "http://rabbitmq-service:15672/api/queues/eda-vhost/${queue}" \
                 -u "$RMQ_USER:$RMQ_PASS" \
                 -H "Content-Type: application/json" \
                 -d '{"auto_delete":true,"durable":false,"arguments":{"x-queue-type":"classic"}}'

            # Bind Queues to Exchange
            curl -X POST -s "http://rabbitmq-service:15672/api/bindings/eda-vhost/e/eda-exchange/q/${queue}" \
                 -u "$RMQ_USER:$RMQ_PASS" \
                 -H "Content-Type: application/json" \
                 -d '{"routing_key":"#"}'
            %{ endfor ~}

            echo "Ambiente RabbitMQ configurado com sucesso!"
            EOT
          ]
          env {
            name  = "RMQ_USER"
            value = var.username
          }
          env {
            name  = "RMQ_PASS"
            value = var.password
          }
        }
        restart_policy = "OnFailure"
      }
    }
  }
  
  lifecycle {
    ignore_changes = [metadata[0].name]
  }
}
