variable "bucket_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

# -------------------------
# Added for ALB + EC2
# -------------------------

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the app server"
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 Key Pair name (optional). Keep null if you don't need SSH."
  default     = null
}

variable "app_port" {
  type        = number
  description = "Port the application listens on inside EC2"
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "ALB target group health check path"
  default     = "/health"
}

variable "alb_ingress_cidr" {
  type        = string
  description = "CIDR allowed to access ALB over HTTP (80)"
  default     = "0.0.0.0/0"
}
variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the ALB HTTPS listener"
}
