terraform {
  backend "s3" {
    bucket         = "serverless-order-pipeline-tf-state-cbrowne-2024"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
