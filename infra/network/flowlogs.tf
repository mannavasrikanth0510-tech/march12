
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "cw_flow_logs" {
  description             = "KMS key for VPC Flow Logs CloudWatch Log Group (${var.environment})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EnableRootPermissions"
        Effect   = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUseOfKey"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-logs/${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cw_flow_logs.arn
  tags = {
    Name        = "vpc-flow-logs-${var.environment}"
    Environment = var.environment
  }
}
#resource "aws_kms_key" "cw_flow_logs" {
 # description             = "KMS key for VPC Flow Logs CloudWatch Log Group (${var.environment})"
  #deletion_window_in_days = 7
  #enable_key_rotation     = true
#}

resource "aws_kms_alias" "cw_flow_logs" {
  name          = "alias/vpc-flow-logs-${var.environment}"
  target_key_id = aws_kms_key.cw_flow_logs.key_id
}
# IAM role assumed by the VPC Flow Logs service
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "vpc_flow_logs_policy_doc" {
  statement {
    sid    = "AllowWriteVPCFlowLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    # tfsec: CloudWatch log streams are created dynamically by the service.
    # We scope to a single log group ARN; wildcard is required for log-stream name.
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:log-stream:*"
    ]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name   = "vpc-flow-logs-policy-${var.environment}"
  role   = aws_iam_role.vpc_flow_logs_role.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_policy_doc.json
}

# Attach flow logs to your VPC
resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_group_name       = aws_cloudwatch_log_group.vpc_flow_logs.name
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn

  tags = {
    Name        = "vpc-flow-log-${var.environment}"
    Environment = var.environment
  }
}
