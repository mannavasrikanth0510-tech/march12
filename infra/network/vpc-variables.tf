variable "vpc_id" {  
  description = "The ID of the VPC"  
  type        = string  
  default     = null  
}  

variable "region" {  
  description = "The AWS region where the VPC is located"  
  type        = string  
  default     = "us-east-1"  
}  

variable "availability_zones" {  
  description = "A list of availability zones to use for the VPC"  
  type        = list(string)  
  default     = ["us-east-1a", "us-east-1b"]  
}  

variable "cidr_block" {  
  description = "The CIDR block for the VPC"  
  type        = string  
  default     = "10.0.0.0/16"  
}  

variable "enable_dns_support" {  
  description = "Whether DNS resolution is supported"  
  type        = bool  
  default     = true  
}  

variable "enable_dns_hostnames" {  
  description = "Whether DNS hostnames are enabled"  
  type        = bool  
  default     = true  
}  
