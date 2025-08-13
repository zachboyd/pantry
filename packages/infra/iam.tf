# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM Policy for SES sending
data "aws_iam_policy_document" "ses_sending" {
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = [
      aws_ses_domain_identity.main.arn,
      aws_ses_configuration_set.main.arn
    ]
  }
}

# SES SMTP User (for applications that need SMTP credentials)
resource "aws_iam_user" "ses_smtp_user" {
  name = "${var.app_name}-${local.environment}-ses-smtp-user"
  path = "/"

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-smtp-user"
    Environment = local.environment
    Application = var.app_name
  }
}

# SES SMTP User Policy
resource "aws_iam_user_policy" "ses_smtp_user" {
  name   = "${var.app_name}-${local.environment}-ses-smtp-policy"
  user   = aws_iam_user.ses_smtp_user.name
  policy = data.aws_iam_policy_document.ses_sending.json
}

# SES SMTP User Access Key
resource "aws_iam_access_key" "ses_smtp_user" {
  user = aws_iam_user.ses_smtp_user.name
}

# IAM role for application use
resource "aws_iam_role" "app_role" {
  name = "${var.app_name}-${local.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.app_name}-${local.environment}-app-role"
    Environment = local.environment
    Application = var.app_name
  }
}

# App Role Policy for SES sending
resource "aws_iam_role_policy" "app_ses" {
  name = "${var.app_name}-${local.environment}-app-ses-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = [
          aws_ses_domain_identity.main.arn,
          aws_ses_configuration_set.main.arn
        ]
      }
    ]
  })
}

# App Role Policy for SSM Parameter Store access
resource "aws_iam_role_policy" "app_ssm" {
  name = "${var.app_name}-${local.environment}-app-ssm-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/${var.app_name}/${local.environment}/*"
        ]
      }
    ]
  })
}

# App Role Policy for ECR access
resource "aws_iam_role_policy" "app_ecr" {
  name = "${var.app_name}-${local.environment}-app-ecr-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = [
          aws_ecr_repository.api.arn,
          "*"  # GetAuthorizationToken requires * resource
        ]
      }
    ]
  })
}