variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "zero-to-prod"
}

variable "account_id" {
  description = "AWS account id (used to make S3 bucket name globally unique)"
  type        = string
  default     = "921810470521"
}

variable "project" {
  description = "Project tag / name prefix"
  type        = string
  default     = "ztd-capstone"
}

variable "ecr_repositories" {
  description = "Service names to create ECR repos for"
  type        = list(string)
  default     = ["frontend", "api-gateway", "orders", "catalog"]
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    Whether to CREATE the account-wide GitHub Actions OIDC provider
    (token.actions.githubusercontent.com). There can be only one per AWS
    account. Set true when this account has no GitHub OIDC provider; set false
    only when the provider already exists and should be looked up.
  EOT
  type        = bool
  default     = true
}
