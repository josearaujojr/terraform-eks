output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.id
}

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "oidc" {
  value = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "certificate_authority" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

output "endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_sg_rule" {
  value = aws_security_group_rule.eks_cluster_sg_rule.id
}

output "eks_cluster_security_group" {
  value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

