variable "admin_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be valid CIDR notation, e.g. 1.2.3.4/32."
  }
}

variable "alert_email" {
  description = "Email address that receives CloudWatch alarm notifications"
  type        = string
}