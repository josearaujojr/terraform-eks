locals {
  tags = {
    Department               = "DevOps"
    Organization             = "Infrastructure and Operations"
    Project                  = "EKS"
    Environment              = "Development"
    "karpenter.sh/discovery" = "app-eks-cluster"
  }
}