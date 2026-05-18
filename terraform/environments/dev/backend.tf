terraform {
  backend "s3" {
    bucket         = "serverless-order-pipeline-tf-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "serverless-order-pipeline-tf-locks"
    encrypt        = true
  }
}
