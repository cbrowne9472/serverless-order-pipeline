output "environment" {
  description = "Active environment"
  value       = var.environment
}

output "orders_table_name" {
  description = "DynamoDB orders table name"
  value       = module.database.table_name
}

output "orders_table_stream_arn" {
  description = "DynamoDB stream ARN — needed when wiring the stream processor Lambda"
  value       = module.database.stream_arn
}

output "order_intake_role_arn" {
  description = "IAM role ARN for the order intake Lambda"
  value       = module.order_intake_role.role_arn
}
