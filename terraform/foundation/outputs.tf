output "cluster_name" {
  description = "Name of the EKS cluster created by the foundation layer"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster created by the foundation layer"
  value       = aws_eks_cluster.this.arn
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "vpc_id" {
  description = "VPC ID used by the new cluster and stack resources"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for the cluster and demo workloads"
  value       = aws_subnet.public[*].id
}

output "system_node_group_name" {
  description = "Name of the baseline system managed node group"
  value       = aws_eks_node_group.system.node_group_name
}

output "ebs_csi_addon_status" {
  description = "Status of the EBS CSI driver add-on"
  value       = aws_eks_addon.ebs_csi.status
}
