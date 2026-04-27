# -----------------------------------------------------------------------------
# Inference Request Log Table
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "ai_inference_logs" {
  name         = "ai-inference-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"
  range_key    = "timestamp"

  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "tenant_id"
    type = "S"
  }

  global_secondary_index {
    name            = "tenant-id-timestamp-index"
    hash_key        = "tenant_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "ai-inference-logs"
  }
}
