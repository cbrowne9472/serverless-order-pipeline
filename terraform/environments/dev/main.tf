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
