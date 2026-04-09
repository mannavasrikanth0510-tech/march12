# -------------------------
# Public Subnet NACL
# -------------------------

resource "aws_network_acl" "public_nacl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "public-nacl-${var.environment}"
  }
}

#tfsec:ignore:aws-ec2-no-public-ingress-acl
resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

#tfsec:ignore:aws-ec2-no-public-ingress-acl
resource "aws_network_acl_rule" "public_inbound_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

#tfsec:ignore:aws-ec2-no-public-ingress-acl
resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

#tfsec:ignore:aws-ec2-no-excessive-port-access
resource "aws_network_acl_rule" "public_outbound_all" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# -------------------------
# Private Subnet NACL
# -------------------------

resource "aws_network_acl" "private_nacl" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "private-nacl-${var.environment}"
  }
}

resource "aws_network_acl_rule" "private_inbound_app" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = var.app_port
  to_port        = var.app_port
}

resource "aws_network_acl_rule" "private_inbound_db" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 1024
  to_port        = 65535
}

#tfsec:ignore:aws-ec2-no-excessive-port-access
resource "aws_network_acl_rule" "private_outbound_all" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}