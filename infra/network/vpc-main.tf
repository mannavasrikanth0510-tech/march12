# -------------------------
# Networking (your existing code)
# -------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.environment}"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = { Name = "public-1-${var.environment}" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = { Name = "public-2-${var.environment}" }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = { Name = "private-1-${var.environment}" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = { Name = "private-2-${var.environment}" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt-${var.environment}" }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "nat-eip-${var.environment}" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id # NAT must be in a public subnet

  tags = { Name = "nat-${var.environment}" }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "private-rt-${var.environment}" }
}

resource "aws_route_table_association" "private_1_assoc" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2_assoc" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# -------------------------
# ALB + EC2 (added)
# ALB in ONE public subnet (public_1)
# EC2 in private subnet (private_1)
# -------------------------
##############################
# Security Group - Public ALB (HTTP redirect + HTTPS)
##############################
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-${var.environment}"
  description = "ALB SG: public internet HTTP/HTTPS"
  vpc_id      = aws_vpc.main.id

  # Ingress: HTTP redirect only
  ingress {
    description = "HTTP redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: HTTPS secure
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress - all outbound allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg-${var.environment}" }
}

##############################
# Security Group - EC2 (private subnet)
##############################
resource "aws_security_group" "app_sg" {
  name        = "app-sg-${var.environment}"
  description = "EC2 SG: allow ALB -> EC2 only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "app-sg-${var.environment}" }
}

##############################
# Public ALB
##############################
resource "aws_lb" "app_alb" {
  name               = "app-alb-${var.environment}"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
  drop_invalid_header_fields = true  # Security best practice

  tags = { Name = "app-alb-${var.environment}" }
}

##############################
# Target Group
##############################
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg-${var.environment}"
  vpc_id   = aws_vpc.main.id
  protocol = "HTTPS"
  port     = var.app_port

  health_check {
    enabled             = true
    protocol            = "HTTPS"
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "app-tg-${var.environment}" }
}

##############################
# ALB Listeners
##############################
# HTTP → redirect to HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.my_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

##############################
# EC2 instance (private subnet)
##############################
resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.key_name

  # Enable IMDS token requirement
  metadata_options {
    http_tokens = "required"
  }

  # Encrypt root volume
  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              dnf -y update
              dnf -y install python3

              cat > /home/ec2-user/app.py <<'PY'
              from http.server import BaseHTTPRequestHandler, HTTPServer

              class Handler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      if self.path in ["/", "/health"]:
                          self.send_response(200)
                          self.end_headers()
                          self.wfile.write(b"OK")
                      else:
                          self.send_response(404)
                          self.end_headers()

              HTTPServer(("0.0.0.0", ${var.app_port}), Handler).serve_forever()
              PY

              nohup python3 /home/ec2-user/app.py > /var/log/app.log 2>&1 &
              EOF

  tags = { Name = "app-${var.environment}" }
}

# Attach EC2 to target group
resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}
