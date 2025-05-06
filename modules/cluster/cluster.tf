data "aws_eks_cluster" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

output "eks_iam_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      var.subnet_pub_1a,
      var.subnet_pub_1b
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_role_attachment
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cluster"
    }
  )
}

resource "null_resource" "wait_for_sg" {
  provisioner "local-exec" {
    command = "sleep 30" # Ajuste o tempo conforme necessário
  }
  depends_on = [aws_eks_cluster.eks_cluster]
}

# Identifica o Security Group após o atraso
data "aws_security_group" "eks_cluster_security_group" {
  filter {
    name   = "group-name"
    values = ["eks-cluster*"] # Altere conforme necessário
  }
  vpc_id     = var.vpc_id
  depends_on = [null_resource.wait_for_sg]
}

resource "null_resource" "tag_eks_sg" {
  provisioner "local-exec" {
    command = <<EOT
      aws ec2 create-tags --resources ${data.aws_security_group.eks_cluster_security_group.id} \
      --tags Key=Department,Value=DevOps Key=Environment,Value=Development Key=Organization,Value="Infrastructure and Operations" Key=Project,Value=EKS Key=karpenter.sh/discovery,Value=app-eks-cluster
    EOT
  }

  depends_on = [aws_eks_cluster.eks_cluster, data.aws_security_group.eks_cluster_security_group]
}

locals {
  tags = {
    Department               = "DevOps"
    Organization             = "Infrastructure and Operations"
    Project                  = "EKS"
    Environment              = "Development"
    "karpenter.sh/discovery" = "app-eks-cluster"
  }
}
