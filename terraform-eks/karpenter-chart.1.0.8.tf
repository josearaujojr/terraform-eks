# module "karpenter" {
#   source  = "terraform-aws-modules/eks/aws//modules/karpenter"
#   version = "19.20.0"

#   cluster_name                    = module.eks_cluster.cluster_name
#   irsa_oidc_provider_arn          = module.eks_cluster.oidc_provider_arn
#   irsa_namespace_service_accounts = ["karpenter:karpenter"]

#   create_iam_role      = false
#   iam_role_arn         = module.eks_managed_node_group.eks_node_group_role_arn
#   irsa_use_name_prefix = false

#   tags = local.tags
# }

# resource "helm_release" "karpenter" {
#   namespace        = "karpenter"
#   create_namespace = true

#   name       = "karpenter"
#   repository = "oci://public.ecr.aws/karpenter"
#   chart      = "karpenter"
#   version    = "1.0.8"

#   set {
#     name  = "settings.aws.clusterName"
#     value = module.eks_cluster.cluster_name
#   }

#   set {
#     name  = "settings.aws.clusterEndpoint"
#     value = module.eks_cluster.endpoint
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.karpenter.irsa_arn
#   }

#   set {
#     name  = "settings.aws.defaultInstanceProfile"
#     value = module.karpenter.instance_profile_name
#   }

#   set {
#     name  = "settings.aws.interruptionQueueName"
#     value = module.karpenter.queue_name
#   }
# }

# resource "kubectl_manifest" "karpenter_global_provisioner" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.sh/v1alpha5
#     kind: GlobalProvisioner
#     metadata:
#       name: default
#     spec:
#       cluster:
#         name: ${module.eks_cluster.cluster_name}
#         endpoint: ${module.eks_cluster.endpoint}
#       provider:
#         subnetSelector:
#           karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
#         securityGroupSelector:
#           karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
#         tags:
#           karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
#       limits:
#         resources:
#           cpu: 1000
#       consolidation:
#         enabled: true
#       ttlSecondsAfterEmpty: 30
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }
