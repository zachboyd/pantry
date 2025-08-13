# SSM Parameters for SES Email Configuration

# SES Configuration Parameters
resource "aws_ssm_parameter" "ses_domain" {
  name        = "/${var.app_name}/${local.environment}/ses/domain"
  description = "SES verified domain"
  type        = "String"
  value       = var.domain_name

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-domain"
    Environment = local.environment
    Application = var.app_name
  }
}

resource "aws_ssm_parameter" "ses_smtp_username" {
  name        = "/${var.app_name}/${local.environment}/ses/smtp_username"
  description = "SES SMTP username"
  type        = "String"
  value       = aws_iam_access_key.ses_smtp_user.id

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-smtp-username"
    Environment = local.environment
    Application = var.app_name
  }
}

resource "aws_ssm_parameter" "ses_smtp_password" {
  name        = "/${var.app_name}/${local.environment}/ses/smtp_password"
  description = "SES SMTP password"
  type        = "SecureString"
  value       = aws_iam_access_key.ses_smtp_user.ses_smtp_password_v4

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-smtp-password"
    Environment = local.environment
    Application = var.app_name
  }
}

resource "aws_ssm_parameter" "ses_configuration_set" {
  name        = "/${var.app_name}/${local.environment}/ses/configuration_set"
  description = "SES configuration set name"
  type        = "String"
  value       = aws_ses_configuration_set.main.name

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-config-set"
    Environment = local.environment
    Application = var.app_name
  }
}

# S3 Configuration Parameters
resource "aws_ssm_parameter" "s3_bucket_name" {
  name        = "/${var.app_name}/${local.environment}/s3/bucket_name"
  description = "S3 bucket name for application storage"
  type        = "String"
  value       = aws_s3_bucket.jeeves_app_bucket.bucket

  tags = {
    Name        = "${var.app_name}-${local.environment}-s3-bucket"
    Environment = local.environment
    Application = var.app_name
  }
}

# ECR Configuration Parameters
resource "aws_ssm_parameter" "ecr_repository_url" {
  name        = "/${var.app_name}/${local.environment}/ecr/repository_url"
  description = "ECR repository URL for Node.js API"
  type        = "String"
  value       = aws_ecr_repository.api.repository_url

  tags = {
    Name        = "${var.app_name}-${local.environment}-ecr-url"
    Environment = local.environment
    Application = var.app_name
  }
}

# General Configuration Parameters
resource "aws_ssm_parameter" "app_environment" {
  name        = "/${var.app_name}/${local.environment}/app/environment"
  description = "Application environment name"
  type        = "String"
  value       = local.environment

  tags = {
    Name        = "${var.app_name}-${local.environment}-app-env"
    Environment = local.environment
    Application = var.app_name
  }
}

resource "aws_ssm_parameter" "app_region" {
  name        = "/${var.app_name}/${local.environment}/app/aws_region"
  description = "AWS region for application"
  type        = "String"
  value       = var.aws_region

  tags = {
    Name        = "${var.app_name}-${local.environment}-app-region"
    Environment = local.environment
    Application = var.app_name
  }
}