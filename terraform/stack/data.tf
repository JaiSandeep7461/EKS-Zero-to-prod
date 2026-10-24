# The foundation root owns the VPC and EKS control plane. This stack reads
# its outputs and creates only additive workloads, a dedicated nodegroup, and
# its supporting resources. Apply terraform/foundation before this directory.

data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = merge(
    {
      bucket = "ztd-capstone-tfstate-921810470521"
      key    = "foundation/terraform.tfstate"
      region = var.region
    },
    var.aws_profile != "" ? { profile = var.aws_profile } : {}
  )
}

locals {
  cluster_name      = data.terraform_remote_state.foundation.outputs.cluster_name
  vpc_id            = data.terraform_remote_state.foundation.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.foundation.outputs.public_subnet_ids
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

# Amazon Linux 2023 AMI for the self-hosted SonarQube EC2 instance.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
