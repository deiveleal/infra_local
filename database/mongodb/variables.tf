variable "namespace" {
  description = "Namespace do Kubernetes para o deploy"
  type        = string
  default     = "default"
}

variable "mongo_root_username" {
  description = "Usuário root do MongoDB"
  type        = string
  default     = "admin"
}

variable "mongo_root_password" {
  description = "Senha root do MongoDB"
  type        = string
  sensitive   = true
}