output "s3_bucket_name" {
  description = "Bucket name for Terraform state storage"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_lock_table_name" {
  description = "DynamoDB table name for Terraform locks"
  value       = aws_dynamodb_table.terraform_locks.name
}
