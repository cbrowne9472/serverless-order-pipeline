resource "aws_dynamodb_table" "orders" {
  name         = "${var.project}-${var.environment}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "customer_email"
    type = "S"
  }

  # Query all orders by status — used by the admin dashboard and pipeline stages
  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  # Query all orders for a given customer
  global_secondary_index {
    name            = "customer-email-index"
    hash_key        = "customer_email"
    projection_type = "ALL"
  }

  # Streams feed every INSERT/MODIFY into EventBridge to drive the pipeline
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }
}
