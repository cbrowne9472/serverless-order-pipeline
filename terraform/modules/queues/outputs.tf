output "stream_processor_dlq_arn" {
  description = "Stream processor DLQ ARN — passed as on_failure destination for the event source mapping"
  value       = aws_sqs_queue.stream_processor_dlq.arn
}

output "stream_processor_dlq_url" {
  description = "Stream processor DLQ URL"
  value       = aws_sqs_queue.stream_processor_dlq.url
}
