# The foundation layer creates the project-owned VPC and EKS cluster.
# Read those outputs from its separate remote state to avoid hardcoded IDs.
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = "ztd-capstone-tfstate-921810470521"
    key    = "foundation/terraform.tfstate"
    region = var.region
  }
}

locals {
  cluster_name        = data.terraform_remote_state.foundation.outputs.cluster_name
  vpc_id              = data.terraform_remote_state.foundation.outputs.vpc_id
  private_subnet_ids  = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  public_subnet_ids   = data.terraform_remote_state.foundation.outputs.public_subnet_ids
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

# Plain Amazon Linux 2023 AMI for the self-managed SonarQube EC2 instance.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
