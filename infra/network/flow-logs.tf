resource "aws_kms_key" "flow_logs" {
  description             = "CMK for VPC Flow Logs (${var.environment})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "kms-flow-logs-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/vpc-flow-logs-${var.environment}"
  target_key_id = aws_kms_key.flow_logs.key_id
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.flow_logs.arn

  tags = {
    Name        = "vpc-flow-logs-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "vpc_flow_logs_policy_doc" {
  statement {
    sid    = "AllowCreateAndWriteFlowLogStreams"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:log-stream:*"
    ]
  }

  statement {
    sid    = "AllowDescribeFlowLogGroup"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.vpc_flow_logs.arn
    ]
  }
}

#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name   = "vpc-flow-logs-policy-${var.environment}"
  role   = aws_iam_role.vpc_flow_logs_role.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_policy_doc.json
}

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
