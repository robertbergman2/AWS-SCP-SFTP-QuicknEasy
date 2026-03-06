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
  description = "Map of SFTP users to create IAM roles and directory mappings for."
  type = map(object({
    home_directory = optional(string)
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

variable "keycloak_url" {
  description = "Base URL of the Keycloak server (e.g., https://keycloak.example.com)"
  type        = string
}

variable "keycloak_realm" {
  description = "Keycloak realm name"
  type        = string
}

variable "keycloak_client_id" {
  description = "Keycloak client ID for the Transfer Family Lambda"
  type        = string
}

variable "keycloak_client_secret" {
  description = "Keycloak client secret for the Transfer Family Lambda"
  type        = string
  sensitive   = true
}
