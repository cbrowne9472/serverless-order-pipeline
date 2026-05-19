locals {
  prefix = "${var.project}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Stream processor DLQ
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "stream_processor_dlq" {
  name                      = "${local.prefix}-stream-processor-dlq"
  message_retention_seconds = 1209600 # 14 days
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

# ---------------------------------------------------------------------------
# Validation DLQ
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "validation_dlq" {
  name                      = "${local.prefix}-validation-dlq"
  message_retention_seconds = 1209600
}

resource "aws_cloudwatch_metric_alarm" "validation_dlq_depth" {
  alarm_name          = "${local.prefix}-validation-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Validation DLQ has messages — an order failed validation processing after retries"

  dimensions = {
    QueueName = aws_sqs_queue.validation_dlq.name
  }
}

# ---------------------------------------------------------------------------
# Inventory DLQ
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "inventory_dlq" {
  name                      = "${local.prefix}-inventory-dlq"
  message_retention_seconds = 1209600
}

resource "aws_cloudwatch_metric_alarm" "inventory_dlq_depth" {
  alarm_name          = "${local.prefix}-inventory-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Inventory DLQ has messages — an order failed inventory processing after retries"

  dimensions = {
    QueueName = aws_sqs_queue.inventory_dlq.name
  }
}

# ---------------------------------------------------------------------------
# Payment DLQ
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "payment_dlq" {
  name                      = "${local.prefix}-payment-dlq"
  message_retention_seconds = 1209600
}

resource "aws_cloudwatch_metric_alarm" "payment_dlq_depth" {
  alarm_name          = "${local.prefix}-payment-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Payment DLQ has messages — an order failed payment processing after retries"

  dimensions = {
    QueueName = aws_sqs_queue.payment_dlq.name
  }
}
