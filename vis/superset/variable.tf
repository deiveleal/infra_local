variable "namespace_name" {
  description = "Kubernetes namespace for Superset"
  type        = string
  default     = "superset-ns"
}

variable "username" {
  description = "Superset admin username"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "Superset admin password"
  type        = string
  default     = "admin"
}

variable "secret_key" {
  description = "Secret key for Flask sessions"
  type        = string
  default     = "YOUR_SECRET_KEY_CHANGE_ME"
}

variable "postgresql_host" {
  description = "PostgreSQL host"
  type        = string
  default     = "postgresql.postgresql-ns"
}

variable "postgresql_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgresql_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "adminuser"
}

variable "postgresql_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "adminuser"
}

variable "postgresql_db" {
  description = "PostgreSQL database for Superset"
  type        = string
  default     = "superset_db"
}

variable "rabbitmq_host" {
  description = "RabbitMQ host"
  type        = string
  default     = "rabbitmq.rabbitmq-ns"
}

variable "rabbitmq_port" {
  description = "RabbitMQ port"
  type        = number
  default     = 5672
}

variable "rabbitmq_user" {
  description = "RabbitMQ username"
  type        = string
  default     = "adminuser"
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  default     = "adminuser"
}
