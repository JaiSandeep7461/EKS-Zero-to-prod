variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use; set to empty for environment/OIDC credentials"
  type        = string
  default     = "zero-to-prod"
}

variable "project" {
  description = "Project tag/name prefix"
  type        = string
  default     = "ztd-capstone"
}

variable "node_instance_type" {
  description = "Instance type for the dedicated platform nodegroup"
  type        = string
  default     = "t3.large"
}

variable "node_desired_size" {
  description = "Desired node count for the platform nodegroup"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count for the platform nodegroup"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count for the platform nodegroup"
  type        = number
  default     = 3
}

variable "node_disk_gib" {
  description = "Root disk size (GiB) for platform nodegroup nodes"
  type        = number
  default     = 30
}

variable "sonar_instance_type" {
  description = "Instance type for the SonarQube EC2 host"
  type        = string
  default     = "t3.medium"
}

variable "sonar_disk_gib" {
  description = "Root disk size (GiB) for the SonarQube EC2 host"
  type        = number
  default     = 30
}

variable "sonar_ingress_cidr" {
  description = <<-EOT
    CIDR allowed to reach SonarQube on :9000. The default exposes the web UI/API
    publicly so GitHub-hosted runners with ephemeral IPs can run scans. Narrow
    this to a trusted CIDR where possible; SonarQube authentication is still required.
  EOT
  type        = string
  default     = "0.0.0.0/0"
}

variable "sonar_db_password" {
  description = "SonarQube Postgres password. Leave empty to auto-generate via random_password (recommended)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "deploy_staging" {
  description = "Toggle for deploying the ztd-capstone app helm_release into staging (release.yml)."
  type        = bool
  default     = false
}

variable "staging_image_tag" {
  description = "Image tag to promote to staging. Set via -var staging_image_tag=sha-<gitsha> by release.yml."
  type        = string
  default     = ""
}

variable "deploy_prod" {
  description = "Toggle for deploying the ztd-capstone app helm_release into prod (release.yml, gated by the GitHub production Environment's manual approval)."
  type        = bool
  default     = false
}

variable "prod_image_tag" {
  description = "Image tag to promote to prod. Set via -var prod_image_tag=sha-<gitsha> by release.yml."
  type        = string
  default     = ""
}
