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

resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "metrics-server"

  tags = merge(var.tags, {
    Name = "${var.project_name}-metrics-server"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "coredns"

  tags = merge(var.tags, {
    Name = "${var.project_name}-coredns"
  })
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "vpc-cni"

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc-cni"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "kube-proxy"

  tags = merge(var.tags, {
    Name = "${var.project_name}-kube-proxy"
  })
}

# IAM Role para o Addon AWS EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${var.project_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:${var.aws_partition}:iam::${var.aws_account_id}:oidc-provider/${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks_cluster.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver_policy_attachment
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-ebs-csi-driver"
  })
}

# IAM Role para o Addon AWS EFS CSI Driver
resource "aws_iam_role" "efs_csi_driver_role" {
  name = "${var.project_name}-efs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:${var.aws_partition}:iam::${var.aws_account_id}:oidc-provider/${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:kube-system:efs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver_role.name
}

resource "aws_eks_addon" "aws_efs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks_cluster.name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = aws_iam_role.efs_csi_driver_role.arn
  depends_on               = [aws_iam_role_policy_attachment.efs_csi_driver_policy_attachment]
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
