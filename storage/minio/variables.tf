
variable "destroy_infra" {
  description = "Destroy the infrastructure"
  type        = bool
  default     = false
}

variable "basic_username" {
  description = "Username for basic auth"
  type        = string
  default     = "admin"
}

variable "basic_password" {
  description = "Password for basic auth"
  type        = string
  default     = "admin"

}

variable "buckets_names" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["bucket1"]
}

variable "region" {
  description = "Region for the S3 bucket"
  type        = string
  default     = "us-east-1"
}
