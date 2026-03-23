# Log group to store VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-logs/${var.environment}"
  retention_in_days = 30

  tags = {
    Name        = "vpc-flow-logs-${var.environment}"
    Environment = var.environment
  }
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

# Policy allowing writes to ONLY this log group
data "aws_iam_policy_document" "vpc_flow_logs_policy_doc" {
  statement {
    sid    = "AllowWriteVPCFlowLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    # tfsec may still dislike this wildcard, but CloudWatch log streams are dynamic.
    # Keep it scoped to this one log group.
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
