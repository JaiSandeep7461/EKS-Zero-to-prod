output "cluster_name" {
  description = "EKS cluster name consumed by the stack layer"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "vpc_id" {
  description = "ID of the dedicated project VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used for external load balancers and SonarQube"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS managed node group"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability Zones used by the foundation"
  value       = local.availability_zones
}

output "nat_gateway_id" {
  description = "NAT Gateway ID for private-subnet outbound access"
  value       = aws_nat_gateway.this.id
}
