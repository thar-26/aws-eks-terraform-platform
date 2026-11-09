variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Short name used to build resource names"
  type        = string
  default     = "aws-eks-terraform-platform"
}