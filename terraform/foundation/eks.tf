data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.project}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Customer-managed key for Kubernetes Secrets. EKS 1.28+ encrypts Secrets
# with envelope encryption by default; this key gives the account explicit
# key ownership, rotation, auditing, and lifecycle control.
resource "aws_kms_key" "eks_secrets" {
  description             = "Kubernetes Secrets encryption for ${var.cluster_name}"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project}-eks-secrets"
  })
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.project}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# Allow the EKS cluster role to use this key for secrets envelope encryption.
# The default key policy retains account-root IAM delegation.
resource "aws_iam_role_policy" "cluster_secrets_encryption" {
  name = "${var.project}-eks-secrets-encryption"
  role = aws_iam_role.cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
        "kms:CreateGrant",
        "kms:ListGrants"
      ]
      Resource = aws_kms_key.eks_secrets.arn
    }]
  })
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  }

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy.cluster_secrets_encryption,
    aws_route_table_association.public,
  ]
}

data "aws_iam_policy_document" "system_node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "system_node" {
  name               = "${var.project}-system-node-role"
  assume_role_policy = data.aws_iam_policy_document.system_node_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "system_node_worker" {
  role       = aws_iam_role.system_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "system_node_cni" {
  role       = aws_iam_role.system_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "system_node_ecr" {
  role       = aws_iam_role.system_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "system_node_ssm" {
  role       = aws_iam_role.system_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project}-system"
  node_role_arn   = aws_iam_role.system_node.arn
  subnet_ids      = aws_subnet.public[*].id

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.system_node_instance_type]
  disk_size      = 20

  scaling_config {
    desired_size = var.system_node_desired_size
    min_size     = var.system_node_min_size
    max_size     = var.system_node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "system"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-system"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.system_node_worker,
    aws_iam_role_policy_attachment.system_node_cni,
    aws_iam_role_policy_attachment.system_node_ecr,
    aws_iam_role_policy_attachment.system_node_ssm,
  ]
}
