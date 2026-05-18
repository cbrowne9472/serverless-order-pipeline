output "role_arn" {
  description = "IAM role ARN — passed to the aws_lambda_function resource"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.this.name
}
