resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project}-${var.environment}"
  description = "Serverless Order Pipeline API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ---------------------------------------------------------------------------
# /orders resource
# ---------------------------------------------------------------------------

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "orders"
}

# POST /orders — order intake
resource "aws_api_gateway_method" "post_orders" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.orders.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "order_intake" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.post_orders.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.order_intake_invoke_arn
}

# GET /orders — list recent orders
resource "aws_api_gateway_method" "get_orders" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.orders.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "order_query_list" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.get_orders.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.order_query_invoke_arn
}

# OPTIONS /orders — CORS preflight
resource "aws_api_gateway_method" "options_orders" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_orders]
}

# ---------------------------------------------------------------------------
# /orders/{order_id} resource
# ---------------------------------------------------------------------------

resource "aws_api_gateway_resource" "order" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{order_id}"
}

# GET /orders/{order_id} — single order lookup
resource "aws_api_gateway_method" "get_order" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.order.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true

  request_parameters = {
    "method.request.path.order_id" = true
  }
}

resource "aws_api_gateway_integration" "order_query_single" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.order.id
  http_method             = aws_api_gateway_method.get_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.order_query_invoke_arn
}

# OPTIONS /orders/{order_id} — CORS preflight
resource "aws_api_gateway_method" "options_order" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.order.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_order" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.options_order.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_order_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.options_order.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_order_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.order.id
  http_method = aws_api_gateway_method.options_order.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.options_order]
}

# ---------------------------------------------------------------------------
# /metrics/dlqs resource
# ---------------------------------------------------------------------------

resource "aws_api_gateway_resource" "metrics" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "metrics"
}

resource "aws_api_gateway_resource" "dlqs" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.metrics.id
  path_part   = "dlqs"
}

resource "aws_api_gateway_method" "get_dlqs" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.dlqs.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "dlq_monitor" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.dlqs.id
  http_method             = aws_api_gateway_method.get_dlqs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.dlq_monitor_invoke_arn
}

resource "aws_api_gateway_method" "options_dlqs" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.dlqs.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_dlqs" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.dlqs.id
  http_method = aws_api_gateway_method.options_dlqs.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_dlqs_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.dlqs.id
  http_method = aws_api_gateway_method.options_dlqs.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_dlqs_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.dlqs.id
  http_method = aws_api_gateway_method.options_dlqs.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_integration.options_dlqs]
}

resource "aws_lambda_permission" "api_gateway_dlq_monitor" {
  statement_id  = "AllowAPIGatewayInvokeDlqMonitor"
  action        = "lambda:InvokeFunction"
  function_name = var.dlq_monitor_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# Deployment & stage
# ---------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_method.post_orders.id,
      aws_api_gateway_integration.order_intake.id,
      aws_api_gateway_method.get_orders.id,
      aws_api_gateway_integration.order_query_list.id,
      aws_api_gateway_method.options_orders.id,
      aws_api_gateway_integration.options_orders.id,
      aws_api_gateway_resource.order.id,
      aws_api_gateway_method.get_order.id,
      aws_api_gateway_integration.order_query_single.id,
      aws_api_gateway_method.options_order.id,
      aws_api_gateway_integration.options_order.id,
      aws_api_gateway_resource.metrics.id,
      aws_api_gateway_resource.dlqs.id,
      aws_api_gateway_method.get_dlqs.id,
      aws_api_gateway_integration.dlq_monitor.id,
      aws_api_gateway_method.options_dlqs.id,
      aws_api_gateway_integration.options_dlqs.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.environment

  xray_tracing_enabled = true
}

# ---------------------------------------------------------------------------
# Lambda permissions
# ---------------------------------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.order_intake_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_order_query" {
  statement_id  = "AllowAPIGatewayInvokeOrderQuery"
  action        = "lambda:InvokeFunction"
  function_name = var.order_query_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# API key + usage plan (throttle + daily quota to prevent bill shock)
# ---------------------------------------------------------------------------

resource "aws_api_gateway_api_key" "dashboard" {
  name    = "${var.project}-${var.environment}-dashboard-key"
  enabled = true
}

resource "aws_api_gateway_usage_plan" "main" {
  name = "${var.project}-${var.environment}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  # Max 10 req/s with burst of 50
  throttle_settings {
    rate_limit  = 10
    burst_limit = 50
  }

  # Hard cap of 500 requests per day
  quota_settings {
    limit  = 500
    period = "DAY"
  }
}

resource "aws_api_gateway_usage_plan_key" "dashboard" {
  key_id        = aws_api_gateway_api_key.dashboard.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}
