resource "null_resource" "edit_aws_auth_configmap" {
  provisioner "local-exec" {
    command = <<EOT
    sleep 60
    aws eks update-kubeconfig --name ${var.cluster_name}

    kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml

    cat <<EOF > aws-auth.yaml
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${var.aws_account_id}:role/app-eks-mng-role
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${var.aws_account_id}:role/KarpenterIRSA-app-eks-cluster
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - userarn: arn:aws:iam::${var.aws_account_id}:user/administrator
      username: administrator
      groups:
        - system:masters
    - userarn: arn:aws:iam::${var.aws_account_id}:root
      username: root-user
      groups:
        - system:masters
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
EOF

    # Aplica as alterações
    kubectl apply -f aws-auth.yaml
    EOT
  }

  depends_on = [
    module.eks_cluster,
    module.eks_managed_node_group,
  ]
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = "ingress-nginx"
  create_namespace = true

  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  version    = "4.11.3"

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }

}

module "eks_network" {
  source       = "./modules/network"
  cidr_block   = var.cidr_block
  project_name = var.project_name
  tags         = local.tags
}

module "eks_cluster" {
  source            = "./modules/cluster"
  project_name      = var.project_name
  tags              = local.tags
  subnet_pub_1a     = module.eks_network.subnet_pub_1a
  subnet_pub_1b     = module.eks_network.subnet_pub_1b
  cluster_name      = var.cluster_name
  aws_partition     = "aws"
  aws_account_id    = var.aws_account_id
  vpc_id = module.eks_network.eks_vpc
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_id = module.eks_cluster.cluster_id
}

module "eks_managed_node_group" {
  source            = "./modules/managed-node-group"
  project_name      = var.project_name
  cluster_name      = module.eks_cluster.cluster_name
  subnet_private_1a = module.eks_network.subnet_priv_1a
  subnet_private_1b = module.eks_network.subnet_priv_1b
  tags              = local.tags
  capacity_type     = "ON_DEMAND"
}

# module "eks_efs_logs" {
#   source             = "./modules/efs"
#   project_name       = var.project_name
#   tags               = local.tags
#   cluster_id         = var.cluster_name
#   eks_vpc_id         = module.eks_network.eks_vpc
#   subnet_priv_1a     = module.eks_network.subnet_priv_1a
#   subnet_priv_1b     = module.eks_network.subnet_priv_1b
#   eks_cluster_sg_id  = module.eks_cluster.eks_cluster_security_group
#   eks_cluster_sg_rule = module.eks_cluster.eks_cluster_sg_rule
#   oidc_issuer_url    = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
# }


module "secret_manager" {
  source       = "./modules/secrets"
  project_name = var.project_name
  oidc_issuer_url    = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  aws_account_id = var.aws_account_id
  # secret_name  = "WASGTEAR-DEV666"
  # description  = "API token for the service"
  # secrets = {
  #   "wf_ds_name" = "teste1234"
  #   "another_key" = "another_value"
  # }
}

# module "eks_ecr" {
#   source            = "./modules/ecr"
#   project_name      = var.project_name
#   tags              = local.tags
# }