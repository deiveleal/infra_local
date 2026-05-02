variable "namespace" {
  description = "Namespace do Kubernetes para o Ollama"
  type        = string
  default     = "ollama-ns"
}

variable "models" {
  description = "Modelos para pré-baixar após a inicialização (ex: ['llama3.2:1b', 'phi3:mini'])"
  type        = list(string)
  default     = ["phi3:latest"]
}
