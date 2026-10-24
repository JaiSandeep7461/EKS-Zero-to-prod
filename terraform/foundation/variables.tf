variable "region" {
  description = "AWS region for the foundation infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for local runs; pass an empty string in CI"
  type        = string
  default     = "zero-to-prod"
}

variable "project" {
  description = "Project tag and resource name prefix"
  type        = string
  default     = "ztd-capstone"
}

variable "cluster_name" {
  description = "EKS cluster name consumed by the stack layer"
  type        = string
  default     = "ztd-demo"
}

variable "cluster_version" {
  description = "EKS Kubernetes minor version"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated project VPC; separate from the account default VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones used for public and private subnets"
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 for this foundation configuration."
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. IAM authentication is still required; restrict this list where possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "EKS control-plane log types delivered to CloudWatch Logs"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}
