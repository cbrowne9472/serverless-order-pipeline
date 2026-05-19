locals {
  function_name = "${var.project}-${var.environment}-${var.function_name}"
}

# Trust policy — allows Lambda to assume this role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Every Lambda must be able to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# X-Ray tracing permission — attached to every function
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Optional additional policy — callers pass a JSON policy document for service-specific permissions
resource "aws_iam_role_policy" "custom" {
  count  = var.policy_json != "" ? 1 : 0
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}

# When a DLQ ARN is provided, failed async invocations route there after retries
resource "aws_lambda_function_event_invoke_config" "this" {
  count         = var.dlq_arn != "" ? 1 : 0
  function_name = aws_lambda_function.this.function_name

  maximum_retry_attempts = 2

  destination_config {
    on_failure {
      destination = var.dlq_arn
    }
  }
}

resource "aws_iam_role_policy" "dlq" {
  count  = var.dlq_arn != "" ? 1 : 0
  name   = "${local.function_name}-dlq-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.dlq[0].json
}

data "aws_iam_policy_document" "dlq" {
  count = var.dlq_arn != "" ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.dlq_arn]
  }
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/builds/${var.function_name}.zip"
}

resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  role             = aws_iam_role.this.arn
  runtime          = "python3.11"
  handler          = var.handler
  filename         = data.archive_file.source.output_path
  source_code_hash = data.archive_file.source.output_base64sha256
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = var.environment_variables
  }

  tracing_config {
    mode = "Active"
  }
}
