resource "aws_security_group" "db_sg" {
  name        = "db-sg-${var.environment}"
  vpc_id      = aws_vpc.main.id
  description = "RDS DB security group for ${var.environment}"

  ingress {
    description     = "Allow MySQL from app EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.private_1.cidr_block, aws_subnet.private_2.cidr_block]
    description = "Allow egress only to private subnets"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-${var.environment}"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "db-subnet-${var.environment}"
  }
}

resource "aws_db_instance" "app_db" {
  identifier                          = "app-db-${var.environment}"
  engine                              = "mysql"
  instance_class                      = "db.t3.micro"
  allocated_storage                   = 20
  db_name                             = "appdb"
  username                            = "admin"
  password                            = var.rds_password # <-- Use a sensitive variable
  publicly_accessible                 = false
  skip_final_snapshot                 = true
  storage_encrypted                   = true
  backup_retention_period             = 7
  iam_database_authentication_enabled = true
  deletion_protection                 = true
  db_subnet_group_name                = aws_db_subnet_group.main.name
  vpc_security_group_ids              = [aws_security_group.db_sg.id]
  multi_az                            = false
  performance_insights_enabled        = true # (Optional, but recommended)
}
