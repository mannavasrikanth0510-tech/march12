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

resource "aws_s3_bucket_public_access_block" "my_bucket_pab" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  bucket = aws_s3_bucket.my_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "s3_kms" {
  description             = "KMS key for ${var.bucket_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "s3_kms_alias" {
  name          = "alias/${var.bucket_name}-kms"
  target_key_id = aws_kms_key.s3_kms.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "my_bucket_sse" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kms.arn
    }
  }
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.bucket_name}-access-logs"

  tags = {
    Name        = "${var.bucket_name}-access-logs"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_logging" "my_bucket_logging" {
  bucket        = aws_s3_bucket.my_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "access-logs/"
}
