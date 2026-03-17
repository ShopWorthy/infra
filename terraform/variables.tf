variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  default = "dev"
}

variable "db_password" {
  default = "shopworthy123"   # Should use secrets manager
}

variable "jwt_secret" {
  default = "shopworthy-secret-2024"
}

variable "gateway_api_key" {
  default = "sk_live_shopworthy_gateway_abc123xyz"  # Should be rotated
}
