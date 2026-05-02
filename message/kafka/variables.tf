variable "namespace" {
  description = "Namespace do Kubernetes para o Kafka"
  type        = string
  default     = "kafka-ns"
}

variable "topics" {
  description = "Tópicos defaults para a plataforma de eventos"
  type        = list(string)
  default     = ["raw-events"]
}