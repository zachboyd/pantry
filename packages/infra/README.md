# Jeeves Infrastructure

This directory contains Terraform configuration for the Jeeves application infrastructure.

## Structure

- `bootstrap/` - One-time setup for Terraform state management
- `environments/` - Environment-specific variable files
- `main.tf` - Provider and backend configuration
- `variables.tf` - Variable definitions
- `s3.tf` - S3 bucket resources for the application
- `outputs.tf` - Output values

## Setup Process

### 1. Bootstrap (One-time setup)

First, create the Terraform state infrastructure:

```bash
cd bootstrap/
terraform init
terraform plan -var="app_name=jeeves" -var="aws_region=us-east-1"
terraform apply -var="app_name=jeeves" -var="aws_region=us-east-1"

# Note the outputs
terraform output
```

### 2. Configure Backend

After bootstrap, uncomment and update the backend configuration in `main.tf`:

```hcl
backend "s3" {
  bucket         = "jeeves-terraform-state"
  key            = "terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "jeeves-terraform-state-lock"
  encrypt        = true
}
```

### 3. Deploy Infrastructure

Deploy to dev environment:

```bash
terraform init
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

Deploy to prod environment:

```bash
terraform plan -var-file=environments/prod.tfvars
terraform apply -var-file=environments/prod.tfvars
```

## Resources Created

### Bootstrap

- S3 bucket: `jeeves-terraform-state`
- DynamoDB table: `jeeves-terraform-state-lock`

### Application (per environment)

- S3 bucket: `jeeves-dev` or `jeeves-prod`
- Versioning enabled
- Server-side encryption
- Public access blocked

## Prerequisites

- AWS CLI configured with SSO
- Terraform installed
- Appropriate AWS permissions for S3 and DynamoDB
