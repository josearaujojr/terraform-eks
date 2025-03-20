provider "aws" {
    region = "us-east-1"
    alias  = "ecr"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.20.0"

  cluster_name                    = module.eks_cluster.cluster_name
  irsa_oidc_provider_arn          = module.eks_cluster.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  create_iam_role      = false
  iam_role_arn = module.eks_managed_node_group.eks_node_group_role_arn
  #iam_role_arn         = "arn:aws:iam::058264204627:role/app-eks-mng-role"#module.eks_cluster.eks_iam_role_arn
  irsa_use_name_prefix = false

  tags = local.tags
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.32.7"

  set {
    name  = "settings.aws.clusterName"
    value = module.eks_cluster.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks_cluster.endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"] #"spot"
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        # - key: "node.kubernetes.io/instance-type"
        #   operator: In
        #   values: ["c5.large","c5a.large", "c5ad.large", "c5d.large", "c6i.large", "t2.medium", "t3.medium", "t3a.medium"]
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: default
      ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
      securityGroupSelector:
        karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
      tags:
        karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}