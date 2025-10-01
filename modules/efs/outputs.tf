output "id" {
  description = "The ID of the EFS File System"
  value       = module.eks_efs_logs.id
}

output "access_points" {
  description = "Map of access points created and their attributes"
  value       = module.eks_efs_logs.access_points
}
