output "state_bucket_name" {
  description = "S3 bucket name — paste this into each environment's backend.tf"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "lock_table_name" {
  description = "DynamoDB lock table name — paste this into each environment's backend.tf"
  value       = aws_dynamodb_table.terraform_locks.name
}
