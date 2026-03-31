variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in tags/names"
  type        = string
  default     = "tf-ec2-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnet"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "EC2 type"
  type        = string
  default     = "t2.micro"
}
variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "terraform-key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed for SSH (use your_ip/32)"
  type        = string
  default     = "0.0.0.0/0"
}
variable "bucket_name" {
  type    = string
}

variable "environment" {
  type    = string
}