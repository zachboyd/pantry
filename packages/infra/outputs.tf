output "pantry_bucket_name" {
  description = "Name of the pantry application S3 bucket"
  value       = aws_s3_bucket.pantry_app_bucket.bucket
}

output "pantry_bucket_arn" {
  description = "ARN of the pantry application S3 bucket"
  value       = aws_s3_bucket.pantry_app_bucket.arn
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}