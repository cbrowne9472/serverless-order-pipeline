output "table_name" {
  description = "Orders table name"
  value       = aws_dynamodb_table.orders.name
}

output "table_arn" {
  description = "Orders table ARN — used when scoping IAM policies"
  value       = aws_dynamodb_table.orders.arn
}

output "stream_arn" {
  description = "DynamoDB Stream ARN — attached to the stream processor Lambda as an event source"
  value       = aws_dynamodb_table.orders.stream_arn
}

output "inventory_table_name" {
  description = "Inventory table name"
  value       = aws_dynamodb_table.inventory.name
}

output "inventory_table_arn" {
  description = "Inventory table ARN — used when scoping IAM policies"
  value       = aws_dynamodb_table.inventory.arn
}
