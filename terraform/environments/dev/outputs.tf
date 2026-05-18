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

output "order_intake_function_name" {
  description = "Order intake Lambda function name"
  value       = module.order_intake.function_name
}

output "api_base_url" {
  description = "API base URL — POST to {api_base_url}/orders to place an order"
  value       = module.api_gateway.base_url
}
