terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  source        = "../../modules/lambda"
  project       = "serverless-order-pipeline"
  environment   = var.environment
  function_name = "order-intake"
  source_dir    = "${path.root}/../../../services/order-intake"
  policy_json   = data.aws_iam_policy_document.order_intake.json

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
  source        = "../../modules/lambda"
  project       = "serverless-order-pipeline"
  environment   = var.environment
  function_name = "stream-processor"
  source_dir    = "${path.root}/../../../services/stream-processor"
  policy_json   = data.aws_iam_policy_document.stream_processor.json

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

# Wire the DynamoDB stream to the stream processor Lambda
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
