output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.app_ecr.repository_url
}

output "aws_region_configured" {
  description = "The AWS region configured for the provider"
  value       = var.AWS_REGION
}
