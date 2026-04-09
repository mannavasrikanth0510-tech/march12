# -------------------------
# Networking
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

  tags = {
    Name = "public-1-${var.environment}"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "public-2-${var.environment}"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "private-1-${var.environment}"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "private-2-${var.environment}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt-${var.environment}"
  }
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

  tags = {
    Name = "nat-eip-${var.environment}"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "nat-${var.environment}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt-${var.environment}"
  }
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
# Security Groups
# -------------------------

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-${var.environment}"
  description = "ALB SG public internet HTTP HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    #tfsec:ignore:aws-ec2-no-public-ingress-sgr
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"

    #tfsec:ignore:aws-ec2-no-public-ingress-sgr
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    #tfsec:ignore:aws-ec2-no-public-egress-sgr
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg-${var.environment}"
  }
}

#tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group" "app_sg" {
  name_prefix = "app-sg-${var.environment}-"
  description = "EC2 SG allow ALB to EC2 only"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description     = "App from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg-${var.environment}"
  }
}

# -------------------------
# Load Balancer
# -------------------------

#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "app_alb" {
  name                       = "app-alb-${var.environment}"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups            = [aws_security_group.alb_sg.id]
  drop_invalid_header_fields = true

  tags = {
    Name = "app-alb-${var.environment}"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name_prefix = "app-tg"
  vpc_id      = aws_vpc.main.id
  protocol    = "HTTP"
  port        = var.app_port

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "app-tg-${var.environment}"
  }
}

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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# -------------------------
# AMI
# -------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -------------------------
# EC2 instance
# -------------------------
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_1.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  key_name                    = var.key_name
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
#!/bin/bash
set -xe
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1

dnf -y update
dnf -y install python3 python3-pip
python3 -m pip install pymysql

cat > /home/ec2-user/app.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import pymysql

DB_HOST = "${aws_db_instance.app_db.address}"
DB_USER = "admin"
DB_PASS = "${var.rds_password}"
DB_NAME = "appdb"

def get_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME
    )

def init_db():
    conn = get_connection()
    with conn.cursor() as cursor:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL
            )
        """)
    conn.commit()
    conn.close()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/" or parsed.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
            <html>
              <head>
                <title>Terraform App</title>
                <style>
                  body {
                    background: linear-gradient(to right, #4facfe, #00f2fe);
                    font-family: Arial, sans-serif;
                    text-align: center;
                    color: blue;
                    margin-top: 80px;
                  }
                  .card {
                    background: rgba(255,255,255,0.9);
                    padding: 30px;
                    border-radius: 12px;
                    display: inline-block;
                    min-width: 350px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.2);
                  }
                  h1 {
                    color: #0b3d91;
                  }
                  p {
                    font-size: 16px;
                  }
                  input {
                    width: 250px;
                    padding: 10px;
                    margin: 8px;
                    border-radius: 6px;
                    border: 1px solid #ccc;
                  }
                  button {
                    background: #0b3d91;
                    color: white;
                    border: none;
                    padding: 10px 20px;
                    border-radius: 6px;
                    cursor: pointer;
                    margin-top: 10px;
                  }
                  a {
                    display: inline-block;
                    margin-top: 15px;
                    color: #0b3d91;
                    text-decoration: none;
                    font-weight: bold;
                  }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>User Registration</h1>
                  <p>Enter your details below</p>
                  <form action="/submit" method="get">
                    <input type="text" name="name" placeholder="Enter Name" required><br>
                    <input type="email" name="email" placeholder="Enter Email" required><br>
                    <button type="submit">Submit</button>
                  </form>
                  <a href="/users">View Users</a>
                </div>
              </body>
            </html>
            """)

        elif parsed.path == "/submit":
            params = parse_qs(parsed.query)
            name = params.get("name", [""])[0]
            email = params.get("email", [""])[0]

            try:
                conn = get_connection()
                with conn.cursor() as cursor:
                    cursor.execute(
                        "INSERT INTO users (name, email) VALUES (%s, %s)",
                        (name, email)
                    )
                conn.commit()
                conn.close()

                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(f"""
                <html>
                  <body style="font-family:Arial; text-align:center; margin-top:100px;">
                    <h2>User added successfully!</h2>
                    <p>Name: {name}</p>
                    <p>Email: {email}</p>
                    <a href="/">Go Back</a><br><br>
                    <a href="/users">View Users</a>
                  </body>
                </html>
                """.encode())

            except Exception as e:
                self.send_response(500)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(f"""
                <html>
                  <body style="font-family:Arial; text-align:center; margin-top:100px;">
                    <h2>Database Error</h2>
                    <p>{str(e)}</p>
                    <a href="/">Go Back</a>
                  </body>
                </html>
                """.encode())

        elif parsed.path == "/users":
            try:
                conn = get_connection()
                with conn.cursor() as cursor:
                    cursor.execute("SELECT name, email FROM users ORDER BY id DESC")
                    rows = cursor.fetchall()
                conn.close()

                html = """
                <html>
                  <head>
                    <title>Users List</title>
                    <style>
                      body { font-family: Arial; text-align: center; margin-top: 60px; background: #f4f8fb; }
                      table { margin: auto; border-collapse: collapse; width: 60%; background: white; }
                      th, td { border: 1px solid #ddd; padding: 12px; }
                      th { background: #0b3d91; color: white; }
                      a { display:inline-block; margin-top:20px; text-decoration:none; color:#0b3d91; font-weight:bold; }
                    </style>
                  </head>
                  <body>
                    <h1>Users List</h1>
                    <table>
                      <tr><th>Name</th><th>Email</th></tr>
                """

                for row in rows:
                    html += f"<tr><td>{row[0]}</td><td>{row[1]}</td></tr>"

                html += """
                    </table>
                    <a href="/">Go Back</a>
                  </body>
                </html>
                """

                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(html.encode())

            except Exception as e:
                self.send_response(500)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(f"""
                <html>
                  <body style="font-family:Arial; text-align:center; margin-top:100px;">
                    <h2>Database Error</h2>
                    <p>{str(e)}</p>
                    <a href="/">Go Back</a>
                  </body>
                </html>
                """.encode())

        elif parsed.path == "/health":
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")

        elif parsed.path == "/info":
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Simple Python HTTP server running on EC2 with RDS")

        else:
            self.send_response(404)
            self.end_headers()
            
#init_db()
#HTTPServer(("0.0.0.0", ${var.app_port}), Handler).serve_forever()
PY

chown ec2-user:ec2-user /home/ec2-user/app.py

cat > /etc/systemd/system/myapp.service <<'SERVICE'
[Unit]
Description=Simple Python HTTP App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/python3 /home/ec2-user/app.py
Restart=always
StandardOutput=append:/var/log/myapp.log
StandardError=append:/var/log/myapp.log

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable myapp
systemctl start myapp
EOF
}
resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = var.app_port
}
