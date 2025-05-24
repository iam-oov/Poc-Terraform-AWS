provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app_ecr" {
  name = "${var.project_name_prefix}/app-ecr"

  tags = {
    Environment = "dev"
  }
}
