# provider "aws" {
#     region = "us-east-1"
#     alias  = "ecr"
# }

# data "aws_ecrpublic_authorization_token" "token" {
#   provider = aws.ecr
# }

# module "karpenter" {
#   source = "terraform-aws-modules/eks/aws//modules/karpenter"
  
#   cluster_name = module.eks_cluster.cluster_name
#   irsa_oidc_provider_arn = module.eks_cluster.oidc_provider_arn
#   irsa_namespace_service_accounts = ["karpenter:karpenter"]
  
#   # Removemos create_iam_role = false para usar a role padrão do módulo
#   # Removemos iam_role_arn para usar a role padrão do módulo
  
#   irsa_use_name_prefix = false
  
#   # Adicionando políticas necessárias
#   iam_role_additional_policies = {
#     AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#     AmazonEKSClusterPolicy = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   }
# }

# resource "helm_release" "karpenter" {
#   namespace = "karpenter"
#   create_namespace = true
  
#   name = "karpenter"
#   repository = "oci://public.ecr.aws/karpenter"
#   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
#   repository_password = data.aws_ecrpublic_authorization_token.token.password
#   chart = "karpenter"
#   version = "1.0.1"

#   values = [
#     <<-EOT
#     settings:
#       clusterName: ${module.eks_cluster.cluster_name}
#       clusterEndpoint: ${module.eks_cluster.endpoint}
#       interruptionQueueName: ${module.karpenter.queue_name}
#     serviceAccount:
#       annotations:
#         eks.amazonaws.com/role-arn: ${module.karpenter.irsa_arn}
#     controller:
#       resources:
#         requests:
#           cpu: 1
#           memory: 1Gi
#         limits:
#           cpu: 1
#           memory: 1Gi
#     EOT
#   ]
# }

# resource "kubectl_manifest" "install_nodepool" {
#   yaml_body = <<-EOT
# apiVersion: karpenter.sh/v1
# kind: NodePool
# metadata:
#   name: default
# spec:
#   template:
#     spec:
#       requirements:
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["amd64"]
#         - key: kubernetes.io/os
#           operator: In
#           values: ["linux"]
#         - key: karpenter.sh/capacity-type
#           operator: In
#           values: ["on-demand"]
#         - key: karpenter.k8s.aws/instance-category
#           operator: In
#           values: ["c", "m", "r"]
#         - key: karpenter.k8s.aws/instance-generation
#           operator: Gt
#           values: ["2"]
#       nodeClassRef:
#         group: karpenter.k8s.aws
#         kind: EC2NodeClass
#         name: default
#       expireAfter: 8m
#   ttlSecondsUntilExpired: 3600
#   ttlSecondsAfterEmpty: 10
  
#   limits:
#     cpu: 50000

#   disruption:
#     consolidationPolicy: WhenEmptyOrUnderutilized
#     consolidateAfter: 1m
#   EOT
# }

# resource "kubectl_manifest" "install_ec2nodeclass" {
#   yaml_body = <<-EOT
# apiVersion: karpenter.k8s.aws/v1
# kind: EC2NodeClass
# metadata:
#   name: default
# spec:
#   amiFamily: AL2 # Amazon Linux 2
#   role: "Karpenter-app-eks-cluster-20250102150510710300000003" # replace with your cluster name
#   subnetSelectorTerms:
#     - tags:
#         karpenter.sh/discovery: "app-eks-cluster" # replace with your cluster name
#   securityGroupSelectorTerms:
#     - tags:
#         karpenter.sh/discovery: "app-eks-cluster" # replace with your cluster name
#   amiSelectorTerms:
#     - id: "ami-0f203b92b9de3e5dc"
#     - id: "ami-0d3cb2ae67f05cf0b"
#     - id: "ami-09ebb4fc0cec3476"
#     - id: "ami-05ffa8a36c3b99b55"
#     - id: "ami-0599933ef0a4c14b9"
#     - id: "ami-0dce5d36564e0714b"
#     EOT

#   depends_on = [
#     module.eks_cluster,
#     module.eks_managed_node_group,
#   ]
# }

####################################################################################

# resource "kubectl_manifest" "karpenter_node_class" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1
#     kind: EC2NodeClass
#     metadata:
#       name: default
#     spec:
#       amiFamily: AL2
#       role: "Karpenter-app-eks-cluster-20241231202501219900000003"
#       subnetSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
#       securityGroupSelectorTerms:
#         - tags:
#             karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
#       amiSelectorTerms:
#         - id: "ami-0599933ef0a4c14b9"
#         - id: "ami-0dce5d36564e0714b"
#       tags:
#         karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }
# module "karpenter" {
#   source = "terraform-aws-modules/eks/aws//modules/karpenter"

#   cluster_name = module.eks_cluster.cluster_name

#   create_iam_role = false
#   irsa_oidc_provider_arn          = module.eks_cluster.oidc_provider_arn
#   iam_role_arn = module.eks_managed_node_group.eks_node_group_role_arn
#   irsa_namespace_service_accounts = ["karpenter:karpenter"]
#   irsa_use_name_prefix = false

#   iam_role_additional_policies = {
#      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#   }
# }

# resource "helm_release" "karpenter" {
#   create_namespace       = true
#   namespace           = "karpenter"
#   name                = "karpenter"
#   repository          = "oci://public.ecr.aws/karpenter"
#   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
#   repository_password = data.aws_ecrpublic_authorization_token.token.password
#   chart               = "karpenter"
#   version             = "1.1.1"
#   wait                = false

#   values = [
#     <<-EOT
#     nodeSelector:
#       karpenter.sh/controller: 'true'
#     dnsPolicy: Default
#     settings:
#       clusterName: ${module.eks_cluster.cluster_name}
#       clusterEndpoint: ${module.eks_cluster.endpoint}
#       interruptionQueue: ${module.karpenter.queue_name}
#     webhook:
#       enabled: false
#     EOT
#   ]
# }

# module "karpenter" {
#   source  = "terraform-aws-modules/eks/aws//modules/karpenter"
#   version = "19.20.0"

#   cluster_name                    = module.eks_cluster.cluster_name
#   irsa_oidc_provider_arn          = module.eks_cluster.oidc_provider_arn
#   irsa_namespace_service_accounts = ["karpenter:karpenter"]

#   create_iam_role      = false
#   iam_role_arn = module.eks_managed_node_group.eks_node_group_role_arn
#   irsa_use_name_prefix = false

#   tags = local.tags
# }

# provider "aws" {
#     region = "us-east-1"
#     alias  = "ecr"
# }

# data "aws_ecrpublic_authorization_token" "token" {
#   provider = aws.ecr
# }

# resource "helm_release" "karpenter" {
#   create_namespace       = true
#   name                            = "karpenter"
#   repository                     = "oci://public.ecr.aws/karpenter"
#     repository_username   = data.aws_ecrpublic_authorization_token.token.user_name
#   repository_password    = data.aws_ecrpublic_authorization_token.token.password
#   version                          = "1.0.1"
#   chart                             = "karpenter"
  
#   namespace                   = "karpenter"


#   set {
#     name  = "settings.clusterName"
#     value = module.eks_cluster.cluster_name
#   }

#   set {
#     name  = "settings.clusterEndpoint"
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

# # resource "helm_release" "karpenter" {
# #   namespace        = "karpenter"
# #   create_namespace = true
# #   name                = "karpenter"
# #   repository          = "oci://public.ecr.aws/karpenter"
# #   chart               = "karpenter"
# #   version             = "1.1.1"
# #   wait                = false

# #   values = [
# #     <<-EOT
# #     nodeSelector:
# #       karpenter.sh/controller: 'true'
# #     dnsPolicy: Default
# #     settings:
# #       clusterName: ${module.eks_cluster.cluster_name}
# #       clusterEndpoint: ${module.eks_cluster.endpoint}
# #       interruptionQueue: ${module.karpenter.queue_name}
# #     webhook:
# #       enabled: false
# #     EOT
# #   ]
# # }

# data "http" "karpenter_nodepools" {
#   url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.7/pkg/apis/crds/karpenter.sh_nodepools.yaml"
# }

# data "http" "karpenter_ec2nodeclasses" {
#   url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.7/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
# }

# data "http" "karpenter_nodeclaims" {
#   url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.7/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
# }

# resource "kubectl_manifest" "karpenter_nodepools_git" {
#   yaml_body = data.http.karpenter_nodepools.body

# }

# resource "kubectl_manifest" "karpenter_ec2nodeclasses" {
#   yaml_body = data.http.karpenter_ec2nodeclasses.body

# }

# resource "kubectl_manifest" "karpenter_nodeclaims" {
#   yaml_body = data.http.karpenter_nodeclaims.body

# }

# resource "kubectl_manifest" "karpenter_provisioner" {
#   yaml_body = <<-YAML
#     apiVersion: karpenter.k8s.aws/v1alpha5
#     kind: Provisioner
#     metadata:
#       name: default
#     spec:
#       requirements:
#         - key: karpenter.sh/capacity-type
#           operator: In
#           values: ["on-demand"] #"spot"
#         - key: karpenter.k8s.aws/instance-category
#           operator: In
#           values: ["c", "m", "r"]
#       limits:
#         resources:
#           cpu: 1000
#       provider:
#         subnetSelector:
#           karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
#         securityGroupSelector:
#           karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
#         tags:
#           karpenter.sh/discovery: "${module.eks_cluster.cluster_name}"
#       ttlSecondsAfterEmpty: 30
#   YAML

#   depends_on = [
#     helm_release.karpenter
#   ]
# }