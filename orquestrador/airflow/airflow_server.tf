resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_deployment" "airflow_deploy" {
  metadata {
    name      = "airflow"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "airflow"
      }
    }

    template {
      metadata {
        labels = {
          app = "airflow"
        }
      }

      spec {
        security_context {
          run_as_user = 50000
          fs_group    = 0
        }

        init_container {
          name    = "fix-permissions"
          image   = "busybox:1.36"
          command = ["sh", "-c", "mkdir -p /opt/airflow/logs/scheduler /opt/airflow/dags && chown -R 50000:0 /opt/airflow/logs /opt/airflow/dags && chmod -R 775 /opt/airflow/logs /opt/airflow/dags"]

          security_context {
            run_as_user = 0
          }

          volume_mount {
            name       = "airflow-data"
            mount_path = "/opt/airflow/dags"
            sub_path   = "dags"
          }

          volume_mount {
            name       = "airflow-data"
            mount_path = "/opt/airflow/logs"
            sub_path   = "logs"
          }
        }

        container {
          image             = "apache/airflow:2.9.1"
          name              = "airflow"
          image_pull_policy = "IfNotPresent"
          command = ["/bin/bash", "-c"]
          args    = ["airflow db migrate && airflow users create --username \"$_AIRFLOW_WWW_USER_USERNAME\" --password \"$_AIRFLOW_WWW_USER_PASSWORD\" --firstname Admin --lastname Admin --role Admin --email admin@example.com || true; airflow scheduler & exec airflow webserver"]

          port {
            container_port = 8080
            name           = "api"
          }

          env {
            name  = "AIRFLOW_HOME"
            value = "/opt/airflow"
          }

          env {
            name  = "_AIRFLOW_WWW_USER_USERNAME"
            value = var.username
          }

          env {
            name  = "_AIRFLOW_WWW_USER_PASSWORD"
            value = var.password
          }

          env {
            name  = "AIRFLOW__CORE__LOAD_EXAMPLES"
            value = var.enable_examples
          }

          env {
            name  = "AIRFLOW__API__AUTH_BACKENDS"
            value = "airflow.api.auth.backend.basic_auth"
          }

          volume_mount {
            name       = "airflow-data"
            mount_path = "/opt/airflow/dags"
            sub_path   = "dags"
          }

          volume_mount {
            name       = "airflow-data"
            mount_path = "/opt/airflow/logs"
            sub_path   = "logs"
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "8Gi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health"
              port   = 8080
              scheme = "HTTP"
            }
            initial_delay_seconds = 90
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path   = "/health"
              port   = 8080
              scheme = "HTTP"
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }
        }

        volume {
          name = "airflow-data"
          host_path {
            path = "/tmp/airflow-data"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "airflow_service" {
  metadata {
    name      = "airflow-service"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "airflow"
    }

    port {
      name        = "api"
      port        = 8080
      target_port = 8080
      node_port   = 30080
    }

    type = "NodePort"
  }
}