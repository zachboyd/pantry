terraform {
  required_version = "1.12.2"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "pantry-terraform-state-cf2fc6a4"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pantry-terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}