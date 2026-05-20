output "order_notifications_arn" {
  description = "ARN of the order notifications SNS topic"
  value       = aws_sns_topic.order_notifications.arn
}

output "order_notifications_name" {
  description = "Name of the order notifications SNS topic"
  value       = aws_sns_topic.order_notifications.name
}
