resource "aws_launch_template" "eks_node_template" {
  name_prefix = "${var.project_name}-node"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${var.project_name}-node"
      }
    )
  }
}

resource "aws_eks_node_group" "eks_managed_node_group" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-nodegroup"
  node_role_arn   = aws_iam_role.eks_mng_role.arn
  subnet_ids      = [var.subnet_private_1a, var.subnet_private_1b]
  capacity_type   = var.capacity_type
  instance_types  = ["t3a.medium"]
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nodegroup"
    }
  )

  scaling_config {
    desired_size = 2
    max_size     = 6
    min_size     = 2
  }

  launch_template {
    id      = aws_launch_template.eks_node_template.id
    version = "$Latest"
  }

  labels = {
    # Used to ensure Karpenter runs on nodes that it does not manage
    "karpenter.sh/controller" = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_mng_attachment_worker,
    aws_iam_role_policy_attachment.eks_mng_attachment_cni,
    aws_iam_role_policy_attachment.eks_mng_attachment_ecr,
  ]
}

output "eks_managed_node_group_name" {
  value = aws_eks_node_group.eks_managed_node_group.node_group_name
}

output "eks_node_group_role_arn" {
  value = aws_iam_role.eks_mng_role.arn
}
