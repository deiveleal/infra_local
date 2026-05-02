
variable "destroy_infra" {
  description = "Destroy the infrastructure"
  type        = bool
  default     = false
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

variable "topic_name" {
  description = "Create  topic  with these names"
  type        = list(string)
  default     = ["eda-queue_1", "eda-queue_2", "eda-queue_3"]
}
