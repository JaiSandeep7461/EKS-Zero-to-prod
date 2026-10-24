variable "region" {
  description = "AWS region in which to create the fresh EKS foundation"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile; set to an empty string when using environment/OIDC credentials"
  type        = string
  default     = "zero-to-prod"
}

variable "project" {
  description = "Project tag/name prefix"
  type        = string
  default     = "ztd-capstone"
}

variable "cluster_name" {
  description = "Name of the new EKS cluster"
  type        = string
  default     = "ztd-demo"
}

variable "cluster_version" {
  description = "Kubernetes minor version for the new EKS cluster"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR block for the new project VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of public subnets/AZs to use (2 or 3); no NAT gateways are created to keep demo costs down"
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. GitHub-hosted runners need broad access because their IPs are ephemeral; restrict this when you use a known runner/operator CIDR."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "system_node_instance_type" {
  description = "Smaller always-on node type for Kubernetes system workloads"
  type        = string
  default     = "t3.small"
}

variable "system_node_desired_size" {
  description = "Desired baseline system node count"
  type        = number
  default     = 1
}

variable "system_node_min_size" {
  description = "Minimum baseline system node count"
  type        = number
  default     = 1
}

variable "system_node_max_size" {
  description = "Maximum baseline system node count"
  type        = number
  default     = 2
}
