locals {
  prefix = "${var.project}-${var.environment}"
}

# --- stream processor DLQ ---
# Catches stream records that fail after bisect-on-error exhausts retries

resource "aws_sqs_queue" "stream_processor_dlq" {
  name                       = "${local.prefix}-stream-processor-dlq"
  message_retention_seconds  = 1209600 # 14 days
}

resource "aws_cloudwatch_metric_alarm" "stream_processor_dlq_depth" {
  alarm_name          = "${local.prefix}-stream-processor-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Stream processor DLQ has messages — a DynamoDB stream record failed processing"

  dimensions = {
    QueueName = aws_sqs_queue.stream_processor_dlq.name
  }
}
