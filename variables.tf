variable "cidr_block" {
  type        = string
  description = "Network CIDR block to be used for the VPC"
}

variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (Name tag)"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "cluster_id" {
  description = "ID do cluster EKS"
  type        = string
  default     = ""
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