provider "aws" {
  region = var.aws_region
}
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.bucket_name}-access-logs"

  tags = {
    Name        = "${var.bucket_name}-access-logs"
    Environment = var.environment
  }
}

# KMS keys
resource "aws_kms_key" "main_bucket_kms" {
  description             = "KMS key for main S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_key" "log_bucket_kms" {
  description             = "KMS key for log S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# Public access block - main bucket
resource "aws_s3_bucket_public_access_block" "my_bucket_pab" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public access block - log bucket
resource "aws_s3_bucket_public_access_block" "log_bucket_pab" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning - main bucket
resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  bucket = aws_s3_bucket.my_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning - log bucket
resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption - main bucket (customer-managed KMS key)
resource "aws_s3_bucket_server_side_encryption_configuration" "my_bucket_sse" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main_bucket_kms.arn
    }
  }
}

# Encryption - log bucket (customer-managed KMS key)
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_sse" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_bucket_kms.arn
    }
  }
}

# Enable access logging on main bucket -> logs go to log bucket
resource "aws_s3_bucket_logging" "my_bucket_logging" {
  bucket        = aws_s3_bucket.my_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}

# Enable access logging on log bucket (self-logging to satisfy tfsec check)
resource "aws_s3_bucket_logging" "log_bucket_logging" {
  bucket        = aws_s3_bucket.log_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "self-access-logs/"
}
