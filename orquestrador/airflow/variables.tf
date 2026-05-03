variable "namespace_name" {
  description = "Nome do namespace do Kubernetes para o Airflow"
  type        = string
  default     = "airflow-ns"
}


variable "username" {
  description = "Username for basic auth"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "Password for basic auth"
  type        = string
  default     = "admin"

}

variable "enable_examples" {
  description = "Flag to enable or disable loading example DAGs in Airflow"
  type        = string
  default     = "False"
  
}