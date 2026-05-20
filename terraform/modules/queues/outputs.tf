output "stream_processor_dlq_arn" {
  description = "Stream processor DLQ ARN"
  value       = aws_sqs_queue.stream_processor_dlq.arn
}

output "stream_processor_dlq_url" {
  description = "Stream processor DLQ URL"
  value       = aws_sqs_queue.stream_processor_dlq.url
}

output "validation_dlq_arn" {
  description = "Validation Lambda DLQ ARN"
  value       = aws_sqs_queue.validation_dlq.arn
}

output "inventory_dlq_arn" {
  description = "Inventory Lambda DLQ ARN"
  value       = aws_sqs_queue.inventory_dlq.arn
}

output "payment_dlq_arn" {
  description = "Payment Lambda DLQ ARN"
  value       = aws_sqs_queue.payment_dlq.arn
}

output "notification_dlq_arn" {
  description = "Notification Lambda DLQ ARN"
  value       = aws_sqs_queue.notification_dlq.arn
}

output "warehouse_dlq_arn" {
  description = "Warehouse Lambda DLQ ARN"
  value       = aws_sqs_queue.warehouse_dlq.arn
}
