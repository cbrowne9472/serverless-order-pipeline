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
