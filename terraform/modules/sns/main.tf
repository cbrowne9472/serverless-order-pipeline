resource "aws_sns_topic" "order_notifications" {
  name = "${var.project}-${var.environment}-order-notifications"
}

# Allow EventBridge to publish to this topic
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.order_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.order_notifications.arn
      }
    ]
  })
}
