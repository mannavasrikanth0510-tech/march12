terraform {
  required_version = ">= 1.8.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket  = "your-bucket-name"
    key     = "your/key/path"
    region  = "your-region"
    dynamodb_table = "my-lock-table" 
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}
