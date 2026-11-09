variable "name" {
  description = "Name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the security group in"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet for the instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}