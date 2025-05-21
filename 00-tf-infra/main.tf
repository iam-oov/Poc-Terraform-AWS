provider "aws" {
  region  = var.AWS_REGION
  profile = "my-dev-profile"
}

# Usamos el Account ID para asegurar nombres de bucket S3 únicos globalmente.
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.PROJECT_NAME_PREFIX}-tfstate-${data.aws_caller_identity.current.account_id}-${var.AWS_REGION}"

  tags = {
    Name        = "${var.PROJECT_NAME_PREFIX}-terraform-state-bucket"
    Environment = "TerraformBackend"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Habilitar versionado para el historial de archivos de estado
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.PROJECT_NAME_PREFIX}-terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST" # Rentable para uso infrecuente como bloqueos de TF
  hash_key     = "LockID"          # La clave de partición DEBE ser "LockID"

  attribute {
    name = "LockID"
    type = "S" # String
  }

  tags = {
    Name        = "${var.PROJECT_NAME_PREFIX}-terraform-lock-table"
    Environment = "TerraformBackend"
    ManagedBy   = "Terraform"
  }
}
