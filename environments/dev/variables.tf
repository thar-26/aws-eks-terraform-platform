variable "admin_cidr" {
  description = "Your public IP in CIDR form, allowed to reach the EKS API"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications"
  type        = string
}