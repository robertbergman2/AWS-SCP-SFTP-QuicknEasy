variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name to use for authentication"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "sftp-external"
}

variable "sftp_users" {
  description = "Map of SFTP users. At least one of password or public_keys must be provided per user."
  type = map(object({
    password       = optional(string)
    home_directory = optional(string)
    public_keys    = optional(list(string), [])
  }))
  default = {}
}

variable "allowed_cidrs" {
  description = "List of allowed source CIDRs (for documentation; public endpoint does not support IP filtering without NLB)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
