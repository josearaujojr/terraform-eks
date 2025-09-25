module "eks_efs_logs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.6.3"

  name           = "${var.project_name}-efs"
  creation_token = "efs-token"

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  # encrypted      = true
  # kms_key_arn    = module.kms_efs.key_arn

  # File system policy
  attach_policy = false
  # bypass_policy_lockout_safety_check = true

  # access_points = {
  #   sonarqube = {
  #     name = "sonarqube"
  #     root_directory = {
  #       path = "/sonarqube"
  #       creation_info = {
  #         owner_gid   = 1000
  #         owner_uid   = 1000
  #         permissions = "777"
  #       }
  #     }
  #   }
  #   "sonarqube-postgres" = {
  #     name = "sonarqube-postgres"
  #     root_directory = {
  #       path = "/sonarqube-postgres"
  #       creation_info = {
  #         owner_gid   = 1000
  #         owner_uid   = 1000
  #         permissions = "777"
  #       }
  #     }
  #   }
  # }
}

resource "aws_efs_mount_target" "subnet_1a" {
  file_system_id  = module.eks_efs_logs.id
  subnet_id       = var.subnet_priv_1a
  security_groups = [var.eks_cluster_sg_id]
}

resource "aws_efs_mount_target" "subnet_1b" {
  file_system_id  = module.eks_efs_logs.id
  subnet_id       = var.subnet_priv_1b
  security_groups = [var.eks_cluster_sg_id]
}

resource "aws_iam_role" "efs_csi_role" {
  name = "${var.project_name}-efs-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::058264204627:oidc-provider/${var.oidc_issuer_url}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${var.oidc_issuer_url}:sub" : "system:serviceaccount:kube-system:${var.project_name}-efs-controller-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "efs_csi_policy_attach" {
  name       = "${var.project_name}-efs-policy"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  roles      = [aws_iam_role.efs_csi_role.name]
}

resource "kubernetes_service_account" "efs_csi_sa" {
  metadata {
    name      = "${var.project_name}-efs-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_role.arn
    }
  }
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name             = "app-eks-cluster"
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = aws_iam_role.efs_csi_role.arn

  depends_on = [aws_iam_role.efs_csi_role, kubernetes_service_account.efs_csi_sa, module.eks_efs_logs]
}
