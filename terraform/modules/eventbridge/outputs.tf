output "event_bus_name" {
  description = "Custom EventBridge event bus name — passed as EVENT_BUS_NAME env var to all pipeline Lambdas"
  value       = aws_cloudwatch_event_bus.this.name
}

output "event_bus_arn" {
  description = "Custom EventBridge event bus ARN — used when scoping IAM put-events policies"
  value       = aws_cloudwatch_event_bus.this.arn
}
