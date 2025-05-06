variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_id" {
  description = "id cluster"
  type        = string
}
variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (Name tag)"
}

variable "tags" {
  type        = map(any)
  description = "Tags to be added to AWS resources"
}

variable "vpc_id" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "subnet_pub_1a" {
  type        = string
  description = "Subnet to create EKS cluster AZ 1a"
}

variable "subnet_pub_1b" {
  type        = string
  description = "Subnet to create EKS cluster AZ 1b"
}

variable "aws_partition" {
  description = "Partição AWS (ex: aws)"
  type        = string
  default     = "aws"
}

variable "aws_account_id" {
  description = "ID da conta AWS"
  type        = string
}

variable "karpenter_version" {
  description = "Versão do Karpenter"
  type        = string
  default     = "v0.29.0" # Atualize conforme necessário
}

variable "karpenter_namespace" {
  description = "Namespace para o Karpenter"
  type        = string
  default     = "karpenter"
}

variable "oidc_provider_arn" {
  description = "ARN do OIDC Provider para IRSA"
  type        = string
}
