output "api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.this.id
}

output "base_url" {
  description = "Base URL for the deployed API — POST to {base_url}/orders to place an order"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

data "aws_region" "current" {}
