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
  value       = local.environment
}


# SES Outputs
output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_domain" {
  description = "SES domain"
  value       = aws_ses_domain_identity.main.domain
}

output "ses_verification_token" {
  description = "SES domain verification token"
  value       = aws_ses_domain_identity.main.verification_token
  sensitive   = true
}

output "ses_dkim_tokens" {
  description = "SES DKIM tokens"
  value       = aws_ses_domain_dkim.main.dkim_tokens
  sensitive   = true
}

output "ses_configuration_set_name" {
  description = "SES configuration set name"
  value       = aws_ses_configuration_set.main.name
}

output "ses_smtp_username" {
  description = "SES SMTP username"
  value       = aws_iam_access_key.ses_smtp_user.id
  sensitive   = true
}

output "ses_smtp_password" {
  description = "SES SMTP password"
  value       = aws_iam_access_key.ses_smtp_user.ses_smtp_password_v4
  sensitive   = true
}

# IAM Role Outputs
output "app_role_arn" {
  description = "ARN of the application role"
  value       = aws_iam_role.app_role.arn
}

output "ses_smtp_user_arn" {
  description = "ARN of the SES SMTP user"
  value       = aws_iam_user.ses_smtp_user.arn
}

# Domain Configuration Instructions
output "domain_configuration_instructions" {
  description = "Instructions for configuring domain with Route53"
  value = <<-EOT
    
    🌐 DOMAIN CONFIGURATION INSTRUCTIONS:
    
    1. UPDATE NAMESERVERS:
       In your domain registrar, update nameservers to:
       ${join("\n       ", aws_route53_zone.main.name_servers)}
    
    2. VERIFY DNS PROPAGATION:
       Check DNS: dig NS ${var.domain_name}
       Should show Route53 nameservers (may take 1-24 hours)
    
    3. YOUR ENDPOINTS WILL BE LIVE:
       Domain: https://${var.domain_name}
       API: https://api.${var.domain_name}
    
  EOT
}

# Route53 and SSL Outputs
output "route53_nameservers" {
  description = "Route53 nameservers to configure in domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "ssl_certificate_domain" {
  description = "Domain covered by SSL certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "ssl_certificate_san" {
  description = "Subject Alternative Names covered by SSL certificate"
  value       = aws_acm_certificate.main.subject_alternative_names
}


# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository for Node.js API"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.api.arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.api.name
}

# SSM Parameter Paths
output "ssm_parameter_paths" {
  description = "SSM parameter paths for application configuration"
  value = {
    ses_domain          = "/${var.app_name}/${local.environment}/ses/domain"
    ses_smtp_username   = "/${var.app_name}/${local.environment}/ses/smtp_username"
    ses_smtp_password   = "/${var.app_name}/${local.environment}/ses/smtp_password"
    ses_configuration_set = "/${var.app_name}/${local.environment}/ses/configuration_set"
    s3_bucket_name      = "/${var.app_name}/${local.environment}/s3/bucket_name"
    ecr_repository_url  = "/${var.app_name}/${local.environment}/ecr/repository_url"
    app_environment     = "/${var.app_name}/${local.environment}/app/environment"
    app_region          = "/${var.app_name}/${local.environment}/app/aws_region"
  }
}

# SES Email Testing Instructions
output "ses_email_instructions" {
  description = "Instructions for testing SES email sending"
  value = <<-EOT
    
    📧 SES EMAIL TESTING INSTRUCTIONS:
    
    1. WAIT FOR DNS PROPAGATION:
       After updating Namecheap nameservers, wait 1-24 hours for DNS to propagate
    
    2. VERIFY SES DOMAIN STATUS:
       aws ses get-identity-verification-attributes --identities ${var.domain_name}
       Should show "Success" status
    
    3. TEST EMAIL SENDING (Node.js example):
       const AWS = require('aws-sdk');
       const ses = new AWS.SES({ region: '${var.aws_region}' });
       
       const params = {
         Destination: { ToAddresses: ['test@example.com'] },
         Message: {
           Body: { Text: { Data: 'Hello from SES!' } },
           Subject: { Data: 'Test Email' }
         },
         Source: 'noreply@${var.domain_name}',
         ConfigurationSetName: '${aws_ses_configuration_set.main.name}'
       };
       
       ses.sendEmail(params).promise();
    
    4. GET SES CREDENTIALS FROM SSM:
       SMTP Username: aws ssm get-parameter --name "/${var.app_name}/${local.environment}/ses/smtp_username"
       SMTP Password: aws ssm get-parameter --name "/${var.app_name}/${local.environment}/ses/smtp_password" --with-decryption
    
    5. YOUR EMAIL DOMAIN:
       Send emails from any address @${var.domain_name}
       Example: noreply@${var.domain_name}, support@${var.domain_name}
    
    ✅ Once DNS propagates, you can send professional emails immediately!
    
  EOT
}