variable "namespace" {
  description = "Namespace do Kubernetes para o deploy"
  type        = string
  default     = "default"
}

variable "username" {
  description = "Usuário root do PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "password" {
  description = "Senha do usuário do PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "host" {
  description = "Endereço do servidor PostgreSQL"
  type        = string
  default     = "localhost"
}

variable "port" {
  description = "Porta do servidor PostgreSQL"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Nome do banco de dados PostgreSQL"
  type        = string
  default     = "postgres"
}