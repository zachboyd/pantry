# SES Domain Identity - each environment gets its own
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# SES Domain DKIM
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# SES Domain Mail From
resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${var.domain_name}"
}

# SES Configuration Set
resource "aws_ses_configuration_set" "main" {
  name = "${var.app_name}-${local.environment}-config-set"

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
}

# SES Configuration Set Event Destination
resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "cloudwatch-destination"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["send", "reject", "bounce", "complaint", "delivery", "open", "click"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "MessageTag"
    value_source   = "messageTag"
  }
}

# CloudWatch Log Group for SES
resource "aws_cloudwatch_log_group" "ses" {
  name              = "/aws/ses/${var.app_name}-${local.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-logs"
    Environment = local.environment
    Application = var.app_name
  }
}

# SES Receipt Rule Set and Rule removed for simplicity
# User only needs email sending capability


# CloudWatch Alarms for SES
resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
  alarm_name          = "${var.app_name}-${local.environment}-ses-bounce-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Bounce"
  namespace           = "AWS/SES"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.05"  # 5% bounce rate threshold
  alarm_description   = "This metric monitors SES bounce rate"
  alarm_actions       = []  # Add SNS topic ARN if you want notifications

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-bounce-alarm"
    Environment = local.environment
    Application = var.app_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate" {
  alarm_name          = "${var.app_name}-${local.environment}-ses-complaint-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Complaint"
  namespace           = "AWS/SES"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.001"  # 0.1% complaint rate threshold
  alarm_description   = "This metric monitors SES complaint rate"
  alarm_actions       = []  # Add SNS topic ARN if you want notifications

  tags = {
    Name        = "${var.app_name}-${local.environment}-ses-complaint-alarm"
    Environment = local.environment
    Application = var.app_name
  }
}