resource "aws_cloudwatch_event_bus" "this" {
  name = "${var.project}-${var.environment}-events"
}
