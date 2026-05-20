terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "serverless-order-pipeline"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "database" {
  source      = "../../modules/database"
  project     = "serverless-order-pipeline"
  environment = var.environment
}

module "order_intake" {
  source            = "../../modules/lambda"
  project           = "serverless-order-pipeline"
  environment       = var.environment
  function_name     = "order-intake"
  source_dir        = "${path.root}/../../../services/order-intake"
  policy_json       = data.aws_iam_policy_document.order_intake.json
  has_custom_policy = true

  environment_variables = {
    ORDERS_TABLE = module.database.table_name
  }
}

# Order intake needs to write new orders and nothing else
data "aws_iam_policy_document" "order_intake" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [module.database.table_arn]
  }
}

module "api_gateway" {
  source                     = "../../modules/api_gateway"
  project                    = "serverless-order-pipeline"
  environment                = var.environment
  order_intake_invoke_arn    = module.order_intake.invoke_arn
  order_intake_function_name = module.order_intake.function_name
}

module "queues" {
  source      = "../../modules/queues"
  project     = "serverless-order-pipeline"
  environment = var.environment
}

module "eventbridge" {
  source      = "../../modules/eventbridge"
  project     = "serverless-order-pipeline"
  environment = var.environment
}

module "stream_processor" {
  source            = "../../modules/lambda"
  project           = "serverless-order-pipeline"
  environment       = var.environment
  function_name     = "stream-processor"
  source_dir        = "${path.root}/../../../services/stream-processor"
  policy_json       = data.aws_iam_policy_document.stream_processor.json
  has_custom_policy = true

  environment_variables = {
    EVENT_BUS_NAME = module.eventbridge.event_bus_name
  }
}

data "aws_iam_policy_document" "stream_processor" {
  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [module.eventbridge.event_bus_arn]
  }

  # Required to read from the DynamoDB stream
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams",
    ]
    resources = [module.database.stream_arn]
  }

  # Required to send failed records to the DLQ
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [module.queues.stream_processor_dlq_arn]
  }
}

locals {
  project = "serverless-order-pipeline"
}

# ---------------------------------------------------------------------------
# Validation Lambda
# ---------------------------------------------------------------------------

module "validation" {
  source            = "../../modules/lambda"
  project           = local.project
  environment       = var.environment
  function_name     = "validation"
  source_dir        = "${path.root}/../../../services/validation"
  policy_json       = data.aws_iam_policy_document.validation.json
  has_custom_policy = true
  dlq_arn           = module.queues.validation_dlq_arn
  has_dlq           = true

  environment_variables = {
    ORDERS_TABLE   = module.database.table_name
    EVENT_BUS_NAME = module.eventbridge.event_bus_name
  }
}

data "aws_iam_policy_document" "validation" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [module.database.table_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [module.eventbridge.event_bus_arn]
  }
}

# ---------------------------------------------------------------------------
# Inventory Lambda
# ---------------------------------------------------------------------------

module "inventory" {
  source            = "../../modules/lambda"
  project           = local.project
  environment       = var.environment
  function_name     = "inventory"
  source_dir        = "${path.root}/../../../services/inventory"
  policy_json       = data.aws_iam_policy_document.inventory.json
  has_custom_policy = true
  dlq_arn           = module.queues.inventory_dlq_arn
  has_dlq           = true

  environment_variables = {
    ORDERS_TABLE    = module.database.table_name
    INVENTORY_TABLE = module.database.inventory_table_name
    EVENT_BUS_NAME  = module.eventbridge.event_bus_name
  }
}

data "aws_iam_policy_document" "inventory" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [module.database.table_arn]
  }

  # Conditional write on the inventory table — UpdateItem with ConditionExpression
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [module.database.inventory_table_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [module.eventbridge.event_bus_arn]
  }
}

# ---------------------------------------------------------------------------
# EventBridge routing rules (Day 1)
# ---------------------------------------------------------------------------

# OrderCreated → Validation Lambda
resource "aws_cloudwatch_event_rule" "order_created" {
  name           = "${local.project}-${var.environment}-order-created"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["order-pipeline"]
    detail-type = ["OrderCreated"]
  })
}

resource "aws_cloudwatch_event_target" "validation" {
  rule           = aws_cloudwatch_event_rule.order_created.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "ValidationLambda"
  arn            = module.validation.function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_validation" {
  statement_id  = "AllowEventBridgeInvokeValidation"
  action        = "lambda:InvokeFunction"
  function_name = module.validation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.order_created.arn
}

# OrderValidated → Inventory Lambda
resource "aws_cloudwatch_event_rule" "order_validated" {
  name           = "${local.project}-${var.environment}-order-validated"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["order-pipeline"]
    detail-type = ["OrderValidated"]
  })
}

resource "aws_cloudwatch_event_target" "inventory" {
  rule           = aws_cloudwatch_event_rule.order_validated.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "InventoryLambda"
  arn            = module.inventory.function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_inventory" {
  statement_id  = "AllowEventBridgeInvokeInventory"
  action        = "lambda:InvokeFunction"
  function_name = module.inventory.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.order_validated.arn
}

# ---------------------------------------------------------------------------
# Payment Lambda
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "stripe_key" {
  name                    = "${local.project}/${var.environment}/stripe-secret-key"
  recovery_window_in_days = 0 # Allow immediate deletion in dev
}

module "payment" {
  source            = "../../modules/lambda"
  project           = local.project
  environment       = var.environment
  function_name     = "payment"
  source_dir        = "${path.root}/../../../services/payment"
  policy_json       = data.aws_iam_policy_document.payment.json
  has_custom_policy = true
  dlq_arn           = module.queues.payment_dlq_arn
  has_dlq           = true

  environment_variables = {
    ORDERS_TABLE      = module.database.table_name
    EVENT_BUS_NAME    = module.eventbridge.event_bus_name
    STRIPE_SECRET_ARN = aws_secretsmanager_secret.stripe_key.arn
  }
}

data "aws_iam_policy_document" "payment" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:UpdateItem"]
    resources = [module.database.table_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["events:PutEvents"]
    resources = [module.eventbridge.event_bus_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.stripe_key.arn]
  }
}

# InventoryReserved → Payment Lambda
resource "aws_cloudwatch_event_rule" "inventory_reserved" {
  name           = "${local.project}-${var.environment}-inventory-reserved"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["order-pipeline"]
    detail-type = ["InventoryReserved"]
  })
}

resource "aws_cloudwatch_event_target" "payment" {
  rule           = aws_cloudwatch_event_rule.inventory_reserved.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "PaymentLambda"
  arn            = module.payment.function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_payment" {
  statement_id  = "AllowEventBridgeInvokePayment"
  action        = "lambda:InvokeFunction"
  function_name = module.payment.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inventory_reserved.arn
}

# PaymentFailed → Inventory Lambda (release stock)
resource "aws_cloudwatch_event_rule" "payment_failed" {
  name           = "${local.project}-${var.environment}-payment-failed"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["order-pipeline"]
    detail-type = ["PaymentFailed"]
  })
}

resource "aws_cloudwatch_event_target" "inventory_release" {
  rule           = aws_cloudwatch_event_rule.payment_failed.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "InventoryReleaseLambda"
  arn            = module.inventory.function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_inventory_release" {
  statement_id  = "AllowEventBridgeInvokeInventoryRelease"
  action        = "lambda:InvokeFunction"
  function_name = module.inventory.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.payment_failed.arn
}

# ---------------------------------------------------------------------------
# Notification Lambda (SES confirmation email on PaymentConfirmed)
# ---------------------------------------------------------------------------

resource "aws_ses_email_identity" "sender" {
  email = "cbrowne2004@gmail.com"
}

module "notification" {
  source            = "../../modules/lambda"
  project           = local.project
  environment       = var.environment
  function_name     = "notification"
  source_dir        = "${path.root}/../../../services/notification"
  policy_json       = data.aws_iam_policy_document.notification.json
  has_custom_policy = true
  dlq_arn           = module.queues.notification_dlq_arn
  has_dlq           = true

  environment_variables = {
    SENDER_EMAIL = aws_ses_email_identity.sender.email
  }
}

data "aws_iam_policy_document" "notification" {
  statement {
    effect    = "Allow"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_event_rule" "payment_confirmed_notification" {
  name           = "${local.project}-${var.environment}-payment-confirmed-notification"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["order-pipeline"]
    detail-type = ["PaymentConfirmed"]
  })
}

resource "aws_cloudwatch_event_target" "notification" {
  rule           = aws_cloudwatch_event_rule.payment_confirmed_notification.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "NotificationLambda"
  arn            = module.notification.function_arn
}

resource "aws_lambda_permission" "eventbridge_invoke_notification" {
  statement_id  = "AllowEventBridgeInvokeNotification"
  action        = "lambda:InvokeFunction"
  function_name = module.notification.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.payment_confirmed_notification.arn
}

# ---------------------------------------------------------------------------
# SNS fan-out + Warehouse Lambda
# ---------------------------------------------------------------------------

module "sns" {
  source      = "../../modules/sns"
  project     = local.project
  environment = var.environment
}

# PaymentConfirmed → SNS topic (warehouse fan-out)
resource "aws_cloudwatch_event_rule" "payment_confirmed_sns" {
  name           = "${local.project}-${var.environment}-payment-confirmed-sns"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["order-pipeline"]
    detail-type = ["PaymentConfirmed"]
  })
}

resource "aws_cloudwatch_event_target" "order_notifications_sns" {
  rule           = aws_cloudwatch_event_rule.payment_confirmed_sns.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "OrderNotificationsSNS"
  arn            = module.sns.order_notifications_arn
}

module "warehouse" {
  source            = "../../modules/lambda"
  project           = local.project
  environment       = var.environment
  function_name     = "warehouse"
  source_dir        = "${path.root}/../../../services/warehouse"
  has_custom_policy = false
  dlq_arn           = module.queues.warehouse_dlq_arn
  has_dlq           = true
}

resource "aws_sns_topic_subscription" "warehouse" {
  topic_arn = module.sns.order_notifications_arn
  protocol  = "lambda"
  endpoint  = module.warehouse.function_arn
}

resource "aws_lambda_permission" "sns_invoke_warehouse" {
  statement_id  = "AllowSNSInvokeWarehouse"
  action        = "lambda:InvokeFunction"
  function_name = module.warehouse.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.sns.order_notifications_arn
}

# ---------------------------------------------------------------------------
# Wire the DynamoDB stream to the stream processor Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  event_source_arn              = module.database.stream_arn
  function_name                 = module.stream_processor.function_arn
  starting_position             = "LATEST"
  batch_size                    = 10
  bisect_batch_on_function_error = true

  destination_config {
    on_failure {
      destination_arn = module.queues.stream_processor_dlq_arn
    }
  }
}
