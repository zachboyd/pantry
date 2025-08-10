output "jeeves_bucket_name" {
  description = "Name of the jeeves application S3 bucket"
  value       = aws_s3_bucket.jeeves_app_bucket.bucket
}

output "jeeves_bucket_arn" {
  description = "ARN of the jeeves application S3 bucket"
  value       = aws_s3_bucket.jeeves_app_bucket.arn
}

output "environment" {
  description = "Current environment"
  value       = var.environment
}