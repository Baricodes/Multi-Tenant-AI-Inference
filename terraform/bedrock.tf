resource "aws_security_group" "bedrock_runtime_vpce" {
  name_prefix = "${var.name_prefix}-bedrock-rt-vpce-"
  description = "Allows HTTPS from the VPC to the Bedrock Runtime interface endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-bedrock-runtime-vpce-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.bedrock_runtime_vpce.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name_prefix}-bedrock-runtime"
  }
}
