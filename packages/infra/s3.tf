resource "aws_s3_bucket" "pantry_app_bucket" {
  bucket = "${var.app_name}-${var.environment}-${var.bucket_suffix}"

  tags = {
    Name        = "${var.app_name}-${var.environment}-${var.bucket_suffix}"
    Environment = var.environment
    Application = var.app_name
  }
}

resource "aws_s3_bucket_versioning" "pantry_app_bucket_versioning" {
  bucket = aws_s3_bucket.pantry_app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pantry_app_bucket_encryption" {
  bucket = aws_s3_bucket.pantry_app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pantry_app_bucket_pab" {
  bucket = aws_s3_bucket.pantry_app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}