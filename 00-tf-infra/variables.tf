variable "AWS_REGION" {
  description = "AWS region for ECR repository"
  type        = string
  default     = "us-east-1"
}

variable "PROJECT_NAME_PREFIX" {
  description = "Prefix for the names of the backend resources to ensure uniqueness."
  type        = string
  default     = "poc-hello-world"
}
