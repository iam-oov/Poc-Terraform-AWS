# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.97"
#     }
#   }
# }

provider "aws" {
  region = var.AWS_REGION
}

resource "aws_ecr_repository" "app_ecr" {
  name = var.ECR_REPOSITORY_NAME

  tags = {
    Environment = "dev"
  }
}
