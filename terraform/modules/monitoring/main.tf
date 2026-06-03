locals {
  prefix = "${var.project}-${var.environment}"

  lambda_functions = [
    "order-intake",
    "stream-processor",
    "validation",
    "inventory",
    "payment",
    "notification",
    "warehouse",
  ]

  dlq_names = [
    "${local.prefix}-stream-processor-dlq",
    "${local.prefix}-validation-dlq",
    "${local.prefix}-inventory-dlq",
    "${local.prefix}-payment-dlq",
    "${local.prefix}-notification-dlq",
    "${local.prefix}-warehouse-dlq",
  ]
}

# ---------------------------------------------------------------------------
# Payment failure metric filter + alarm
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "payment_failures" {
  name           = "${local.prefix}-payment-failures"
  log_group_name = "/aws/lambda/${local.prefix}-payment"
  pattern        = "{ $.event = \"payment_failed\" }"

  metric_transformation {
    name      = "PaymentFailures"
    namespace = "${var.project}/pipeline"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "payment_failure_rate" {
  alarm_name          = "${local.prefix}-high-payment-failure-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "PaymentFailures"
  namespace           = "${var.project}/pipeline"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"
  alarm_description   = "More than 3 card failures in a 5-minute window — possible bad card batch or Stripe issue"
}

# ---------------------------------------------------------------------------
# CloudWatch dashboard
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.prefix

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Invocations + Errors
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Invocations"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            for fn in local.lambda_functions :
            ["AWS/Lambda", "Invocations", "FunctionName", "${local.prefix}-${fn}"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Errors"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            for fn in local.lambda_functions :
            ["AWS/Lambda", "Errors", "FunctionName", "${local.prefix}-${fn}"]
          ]
        }
      },
      # Row 2: Duration + DLQ depths
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Duration p95 (ms)"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          metrics = [
            for fn in local.lambda_functions :
            ["AWS/Lambda", "Duration", "FunctionName", "${local.prefix}-${fn}", { "stat" : "p95" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DLQ Depth (messages visible)"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          stat    = "Maximum"
          metrics = [
            for q in local.dlq_names :
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", q]
          ]
        }
      },
      # Row 3: API Gateway + Payment failures
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "API Gateway — Requests & Errors"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", local.prefix, "Stage", var.environment, { "stat" : "Sum", "label" : "Requests" }],
            ["AWS/ApiGateway", "4XXError", "ApiName", local.prefix, "Stage", var.environment, { "stat" : "Sum", "label" : "4XX" }],
            ["AWS/ApiGateway", "5XXError", "ApiName", local.prefix, "Stage", var.environment, { "stat" : "Sum", "label" : "5XX" }],
            # Note: API name matches aws_api_gateway_rest_api.this.name = "${project}-${environment}"
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "Payment Failures (card declined)"
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          period  = 300
          stat    = "Sum"
          metrics = [
            ["${var.project}/pipeline", "PaymentFailures"]
          ]
          annotations = {
            horizontal = [
              {
                label = "Alarm threshold"
                value = 3
                color = "#ff0000"
              }
            ]
          }
        }
      },
    ]
  })
}
