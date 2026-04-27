# -----------------------------------------------------------------------------
# Route Matrix
# -----------------------------------------------------------------------------

locals {
  api_gateway_tenants         = toset(["tenant-a", "tenant-b"])
  api_gateway_model_endpoints = toset(["summarize", "generate", "embed"])
  api_gateway_routes = {
    for route in setproduct(local.api_gateway_tenants, local.api_gateway_model_endpoints) :
    "${route[0]}-${route[1]}" => {
      tenant   = route[0]
      endpoint = route[1]
    }
  }
}

# -----------------------------------------------------------------------------
# VPC Link
# -----------------------------------------------------------------------------

resource "aws_api_gateway_vpc_link" "platform" {
  name        = var.api_gateway_vpc_link_name
  description = "VPC Link from API Gateway REST API to the internal platform NLB."
  target_arns = [aws_lb.platform_nlb.arn]

  tags = {
    Name = var.api_gateway_vpc_link_name
  }
}

# -----------------------------------------------------------------------------
# REST API
# -----------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "inference" {
  name        = var.api_gateway_rest_api_name
  description = "REST API entry point for tenant AI inference endpoints."

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = var.api_gateway_rest_api_name
  }
}

# -----------------------------------------------------------------------------
# Tenant and Model Path Resources
# -----------------------------------------------------------------------------

resource "aws_api_gateway_resource" "tenant" {
  for_each = local.api_gateway_tenants

  rest_api_id = aws_api_gateway_rest_api.inference.id
  parent_id   = aws_api_gateway_rest_api.inference.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_resource" "model" {
  for_each = local.api_gateway_routes

  rest_api_id = aws_api_gateway_rest_api.inference.id
  parent_id   = aws_api_gateway_resource.tenant[each.value.tenant].id
  path_part   = each.value.endpoint
}

# -----------------------------------------------------------------------------
# POST Methods and HTTP Proxy Integrations
# -----------------------------------------------------------------------------

resource "aws_api_gateway_method" "model_post" {
  for_each = local.api_gateway_routes

  rest_api_id      = aws_api_gateway_rest_api.inference.id
  resource_id      = aws_api_gateway_resource.model[each.key].id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "model_post" {
  for_each = local.api_gateway_routes

  rest_api_id             = aws_api_gateway_rest_api.inference.id
  resource_id             = aws_api_gateway_resource.model[each.key].id
  http_method             = aws_api_gateway_method.model_post[each.key].http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.platform_nlb.dns_name}/${each.value.tenant}/${each.value.endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.platform.id
}

# -----------------------------------------------------------------------------
# Deployment and Stage
# -----------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "inference" {
  rest_api_id = aws_api_gateway_rest_api.inference.id

  triggers = {
    redeployment = sha1(jsonencode({
      tenants      = { for tenant, resource in aws_api_gateway_resource.tenant : tenant => resource.id }
      resources    = { for endpoint, resource in aws_api_gateway_resource.model : endpoint => resource.id }
      methods      = { for endpoint, method in aws_api_gateway_method.model_post : endpoint => method.id }
      integrations = { for endpoint, integration in aws_api_gateway_integration.model_post : endpoint => "${integration.id}:${integration.uri}" }
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.model_post]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.inference.id
  deployment_id = aws_api_gateway_deployment.inference.id
  stage_name    = var.api_gateway_stage_name

  tags = {
    Name = "${var.api_gateway_rest_api_name}-${var.api_gateway_stage_name}"
  }
}

# -----------------------------------------------------------------------------
# Tenant-A Access Controls
# -----------------------------------------------------------------------------

resource "aws_api_gateway_usage_plan" "tenant_a" {
  name        = var.tenant_a_usage_plan_name
  description = "Usage plan for tenant-a inference API access."

  api_stages {
    api_id = aws_api_gateway_rest_api.inference.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  throttle_settings {
    rate_limit  = var.tenant_a_throttle_rate_limit
    burst_limit = var.tenant_a_throttle_burst_limit
  }

  quota_settings {
    limit  = var.tenant_a_monthly_quota_limit
    period = "MONTH"
  }

  tags = {
    Name = var.tenant_a_usage_plan_name
  }
}

resource "aws_api_gateway_api_key" "tenant_a" {
  name        = var.tenant_a_api_key_name
  description = "API key for tenant-a inference requests."
  enabled     = true

  tags = {
    Name = var.tenant_a_api_key_name
  }
}

resource "aws_api_gateway_usage_plan_key" "tenant_a" {
  key_id        = aws_api_gateway_api_key.tenant_a.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.tenant_a.id
}

# -----------------------------------------------------------------------------
# Tenant-B Access Controls
# -----------------------------------------------------------------------------

resource "aws_api_gateway_usage_plan" "tenant_b" {
  name        = var.tenant_b_usage_plan_name
  description = "Usage plan for tenant-b inference API access."

  api_stages {
    api_id = aws_api_gateway_rest_api.inference.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  throttle_settings {
    rate_limit  = var.tenant_b_throttle_rate_limit
    burst_limit = var.tenant_b_throttle_burst_limit
  }

  quota_settings {
    limit  = var.tenant_b_monthly_quota_limit
    period = "MONTH"
  }

  tags = {
    Name = var.tenant_b_usage_plan_name
  }
}

resource "aws_api_gateway_api_key" "tenant_b" {
  name        = var.tenant_b_api_key_name
  description = "API key for tenant-b inference requests."
  enabled     = true

  tags = {
    Name = var.tenant_b_api_key_name
  }
}

resource "aws_api_gateway_usage_plan_key" "tenant_b" {
  key_id        = aws_api_gateway_api_key.tenant_b.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.tenant_b.id
}
