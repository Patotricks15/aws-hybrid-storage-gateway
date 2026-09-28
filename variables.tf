variable "project_name" {
  description = "Project name used as prefix for all resources."
  type        = string
  default     = "floci-hybrid-storage-gateway"
}

variable "aws_region" {
  description = "AWS region (simulated by floci)."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC hosting the Storage Gateway VPN endpoint."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the gateway subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "on_premises_router_ip" {
  description = "Public IP of the on-premises customer gateway router (simulated)."
  type        = string
  default     = "203.0.113.1"
}

variable "ops_notification_email" {
  description = "Email address subscribed to storage/backup operational alarms."
  type        = string
  default     = "storage-ops@example.com"
}
