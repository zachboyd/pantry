variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "app_name" {
  description = "Application name for resource naming"
  type        = string
  default     = "pantry"
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