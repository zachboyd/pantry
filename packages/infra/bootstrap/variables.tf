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