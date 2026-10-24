# Additive EKS access for the bootstrap-created GitHub Actions role.
# The role can deploy namespaced application resources in dev/staging/prod.
# It receives no cluster-admin policy and no access to foundation resources.

data "aws_iam_role" "ci" {
  name = "${var.project}-ci"
}

resource "aws_eks_access_entry" "ci" {
  cluster_name  = local.cluster_name
  principal_arn = data.aws_iam_role.ci.arn
  type          = "STANDARD"

  tags = {
    project    = var.project
    managed-by = "terraform"
    layer      = "stack"
  }
}

resource "aws_eks_access_policy_association" "ci_apps_edit" {
  cluster_name  = local.cluster_name
  principal_arn = data.aws_iam_role.ci.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["dev", "staging", "prod"]
  }
}
