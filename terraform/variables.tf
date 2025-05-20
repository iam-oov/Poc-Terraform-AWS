variable "AWS_REGION" {
  description = "AWS region for ECR repository"
  type        = string
  default     = "us-east-1"
}

variable "ECR_REPOSITORY_NAME" {
  description = "Name for the ECR repository"
  type        = string
  default     = "poc-hello-world"
}
