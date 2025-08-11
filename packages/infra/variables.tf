# Environment is determined by Terraform workspace
locals {
  environment = terraform.workspace
}

variable "app_name" {
  description = "Application name for resource naming"
  type        = string
  default     = "jeeves"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_suffix" {
  description = "Random suffix for bucket names to ensure global uniqueness"
  type        = string
}

# Domain Configuration
variable "domain_name" {
  description = "Main domain name (e.g., jeevesapp.com)"
  type        = string
  default     = "jeevesapp.com"
}


