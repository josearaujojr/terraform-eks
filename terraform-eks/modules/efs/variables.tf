variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (Name tag)"
}

variable "cluster_id" {
  type        = string
  description = "Project name to be used to name the resources (Name tag)"
}

variable "tags" {
  type        = map(any)
  description = "Tags to be added to AWS resources"
}

variable "subnet_priv_1a" {
  type        = string
  description = "Subnet to create EKS cluster AZ 1a"
}

variable "subnet_priv_1b" {
  type        = string
  description = "Subnet to create EKS cluster AZ 1b"
}

variable "eks_vpc_id" {
  type        = string
  description = "The Id of the VPC"
}

variable "eks_cluster_sg_rule" {
  type        = string
  description = "The Id of the SG Cluster"
}

variable "eks_cluster_sg_id" {
  type        = string
  description = "The Security Group ID for the EKS cluster"
}

variable "oidc_issuer_url" {
  type = string
}
