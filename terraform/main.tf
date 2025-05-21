# ! [PEND]: hacer global la region atravez de variables de bash
# ! [PEND]: al igual que el nombre del bucket y la tabla de locks

terraform {
  backend "s3" {
    bucket         = "poc-hello-world-tfstate-058264118467-us-east-1" # S3 bucket name
    key            = "states/poc-hello-world/terraform.tfstate"       # State file path in the bucket
    region         = "us-east-1"                                      # AWS region
    dynamodb_table = "poc-hello-world-terraform-lock-table"           # DynamoDB table name
    encrypt        = true                                             # Encryption enabled
  }
}

provider "aws" {
  region = var.AWS_REGION
}

resource "aws_ecr_repository" "app_ecr" {
  name = var.ECR_REPOSITORY_NAME

  tags = {
    Environment = "dev"
  }
}
