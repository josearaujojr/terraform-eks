# #################### ROLE KARPENTER NODE

# # Define o documento de política de trust
# data "aws_iam_policy_document" "karpenter_node_trust_policy" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# # Cria a role do Karpenter para os nodes
# resource "aws_iam_role" "karpenter_node_role" {
#   name               = "KarpenterNodeRole-${var.cluster_name}"
#   assume_role_policy = data.aws_iam_policy_document.karpenter_node_trust_policy.json
# }

# # Anexa a política AmazonEKSWorkerNodePolicy
# resource "aws_iam_role_policy_attachment" "karpenter_node_eks_worker_policy" {
#   role       = aws_iam_role.karpenter_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
# }

# # Anexa a política AmazonEKS_CNI_Policy
# resource "aws_iam_role_policy_attachment" "karpenter_node_eks_cni_policy" {
#   role       = aws_iam_role.karpenter_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# }

# # Anexa a política AmazonEC2ContainerRegistryReadOnly
# resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_readonly_policy" {
#   role       = aws_iam_role.karpenter_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# }

# # Anexa a política AmazonSSMManagedInstanceCore
# resource "aws_iam_role_policy_attachment" "karpenter_node_ssm_policy" {
#   role       = aws_iam_role.karpenter_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

# #################### ROLE KARPENTER CONTROLLER

# data "aws_iam_openid_connect_provider" "oidc" {
#   url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
# }

# data "aws_iam_policy_document" "karpenter_controller_trust_policy" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Federated"
#       identifiers = [data.aws_iam_openid_connect_provider.oidc.arn]
#     }

#     actions = ["sts:AssumeRoleWithWebIdentity"]

#     condition {
#       test     = "StringEquals"
#       variable = "${data.aws_iam_openid_connect_provider.oidc.url}:aud"
#       values   = ["sts.amazonaws.com"]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "${data.aws_iam_openid_connect_provider.oidc.url}:sub"
#       values   = ["system:serviceaccount:kube-system:karpenter"]
#     }
#   }
# }


# # Anexa a policy AmazonEC2FullAccess à role do Karpenter Controller
# resource "aws_iam_role_policy_attachment" "karpenter_ec2_full_access" {
#   role       = aws_iam_role.karpenter_controller_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
# }

# # Cria a role do Karpenter Controller
# resource "aws_iam_role" "karpenter_controller_role" {
#   name               = "KarpenterControllerRole-${var.cluster_name}"
#   assume_role_policy = data.aws_iam_policy_document.karpenter_controller_trust_policy.json
# }

# resource "aws_iam_policy" "karpenter_policy" {
#   name        = "KarpenterPolicy-${var.cluster_name}"
#   description = "Policy for Karpenter nodes to interact with EC2 and other services"
#   policy      = <<POLICY
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Action": [
#                 "ssm:GetParameter",
#                 "ec2:DescribeImages",
#                 "ec2:RunInstances",
#                 "ec2:DescribeSubnets",
#                 "ec2:DescribeSecurityGroups",
#                 "ec2:DescribeLaunchTemplates",
#                 "ec2:DescribeInstances",
#                 "ec2:DescribeInstanceTypes",
#                 "ec2:DescribeInstanceTypeOfferings",
#                 "ec2:DescribeAvailabilityZones",
#                 "ec2:DeleteLaunchTemplate",
#                 "ec2:CreateTags",
#                 "ec2:CreateLaunchTemplate",
#                 "ec2:CreateFleet",
#                 "ec2:DescribeSpotPriceHistory",
#                 "pricing:GetProducts"
#             ],
#             "Effect": "Allow",
#             "Resource": "*",
#             "Sid": "Karpenter"
#         },
#         {
#             "Action": "ec2:TerminateInstances",
#             "Condition": {
#                 "StringLike": {
#                     "ec2:ResourceTag/karpenter.sh/nodepool": "*"
#                 }
#             },
#             "Effect": "Allow",
#             "Resource": "*",
#             "Sid": "ConditionalEC2Termination"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "iam:PassRole",
#             "Resource": "arn:aws:iam::${var.aws_account_id}:role/KarpenterNodeRole-${var.cluster_name}",
#             "Sid": "PassNodeIAMRole"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "eks:DescribeCluster",
#             "Resource": "arn:aws:eks:us-east-2:${var.aws_account_id}:cluster/${var.cluster_name}",
#             "Sid": "EKSClusterEndpointLookup"
#         },
#         {
#             "Sid": "AllowScopedInstanceProfileCreationActions",
#             "Effect": "Allow",
#             "Resource": "*",
#             "Action": [
#                 "iam:CreateInstanceProfile"
#             ],
#             "Condition": {
#                 "StringEquals": {
#                     "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
#                     "aws:RequestTag/topology.kubernetes.io/region": "us-east-2"
#                 },
#                 "StringLike": {
#                     "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
#                 }
#             }
#         },
#         {
#             "Sid": "AllowScopedInstanceProfileTagActions",
#             "Effect": "Allow",
#             "Resource": "*",
#             "Action": [
#                 "iam:TagInstanceProfile"
#             ],
#             "Condition": {
#                 "StringEquals": {
#                     "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
#                     "aws:ResourceTag/topology.kubernetes.io/region": "us-east-2",
#                     "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
#                     "aws:RequestTag/topology.kubernetes.io/region": "us-east-2"
#                 },
#                 "StringLike": {
#                     "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*",
#                     "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass": "*"
#                 }
#             }
#         },
#         {
#             "Sid": "AllowScopedInstanceProfileActions",
#             "Effect": "Allow",
#             "Resource": "*",
#             "Action": [
#                 "iam:AddRoleToInstanceProfile",
#                 "iam:RemoveRoleFromInstanceProfile",
#                 "iam:DeleteInstanceProfile"
#             ],
#             "Condition": {
#                 "StringEquals": {
#                     "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}": "owned",
#                     "aws:ResourceTag/topology.kubernetes.io/region": "us-east-2"
#                 },
#                 "StringLike": {
#                     "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass": "*"
#                 }
#             }
#         },
#         {
#             "Sid": "AllowInstanceProfileReadActions",
#             "Effect": "Allow",
#             "Resource": "*",
#             "Action": "iam:GetInstanceProfile"
#         }
#     ]
# }
# POLICY
# }

# resource "aws_iam_role_policy_attachment" "karpenter_policy_attachment" {
#   role       = aws_iam_role.karpenter_controller_role.name
#   policy_arn = aws_iam_policy.karpenter_policy.arn

#   depends_on = [
#     aws_iam_role.karpenter_controller_role,
#     aws_iam_policy.karpenter_policy
#   ]
# }

# data "http" "karpenter_nodepools_git" {
#   url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.1/pkg/apis/crds/karpenter.sh_nodepools.yaml"
# }

# data "http" "karpenter_ec2nodeclasses" {
#   url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.1/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
# }

# data "http" "karpenter_nodeclaims" {
#   url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.0.1/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
# }

# resource "kubectl_manifest" "karpenter_nodepools_git" {
#   yaml_body = data.http.karpenter_nodepools_git.body

#   depends_on = [
#     module.eks_cluster,
#   ]
# }

# resource "kubectl_manifest" "karpenter_ec2nodeclasses" {
#   yaml_body = data.http.karpenter_ec2nodeclasses.body

#   depends_on = [
#     module.eks_cluster,
#   ]
# }

# resource "kubectl_manifest" "karpenter_nodeclaims" {
#   yaml_body = data.http.karpenter_nodeclaims.body

#   depends_on = [
#     module.eks_cluster,
#   ]
# }


# resource "kubectl_manifest" "install_karpenter" {

#   yaml_body = <<-EOT
#     apiVersion: policy/v1
#     kind: PodDisruptionBudget
#     metadata:
#       name: karpenter
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     spec:
#       maxUnavailable: 1
#       selector:
#         matchLabels:
#           app.kubernetes.io/name: karpenter
#           app.kubernetes.io/instance: karpenter
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter2" {

#   yaml_body = <<-EOT
#     apiVersion: v1
#     kind: ServiceAccount
#     metadata:
#       name: karpenter
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#       annotations:
#         eks.amazonaws.com/role-arn: arn:aws:iam::058264204627:role/KarpenterControllerRole-app-eks-cluster
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter3" {

#   yaml_body = <<-EOT
#     apiVersion: v1
#     kind: Secret
#     metadata:
#       name: karpenter-cert
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter4" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: ClusterRole
#     metadata:
#       name: karpenter-admin
#       labels:
#         rbac.authorization.k8s.io/aggregate-to-admin: "true"
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     rules:
#       - apiGroups: ["karpenter.sh"]
#         resources: ["nodepools", "nodepools/status", "nodeclaims", "nodeclaims/status"]
#         verbs: ["get", "list", "watch", "create", "delete", "patch"]
#       - apiGroups: ["karpenter.k8s.aws"]
#         resources: ["ec2nodeclasses"]
#         verbs: ["get", "list", "watch", "create", "delete", "patch"]
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter5" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: ClusterRole
#     metadata:
#       name: karpenter-core
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     rules:
#       # Read
#       - apiGroups: ["karpenter.sh"]
#         resources: ["nodepools", "nodepools/status", "nodeclaims", "nodeclaims/status"]
#         verbs: ["get", "list", "watch"]
#       - apiGroups: [""]
#         resources: ["pods", "nodes", "persistentvolumes", "persistentvolumeclaims", "replicationcontrollers", "namespaces"]
#         verbs: ["get", "list", "watch"]
#       - apiGroups: ["storage.k8s.io"]
#         resources: ["storageclasses", "csinodes", "volumeattachments"]
#         verbs: ["get", "watch", "list"]
#       - apiGroups: ["apps"]
#         resources: ["daemonsets", "deployments", "replicasets", "statefulsets"]
#         verbs: ["list", "watch"]
#       - apiGroups: ["apiextensions.k8s.io"]
#         resources: ["customresourcedefinitions"]
#         verbs: ["watch", "list"]
#       - apiGroups: ["policy"]
#         resources: ["poddisruptionbudgets"]
#         verbs: ["get", "list", "watch"]
#       # Write
#       - apiGroups: ["karpenter.sh"]
#         resources: ["nodeclaims", "nodeclaims/status"]
#         verbs: ["create", "delete", "update", "patch"]
#       - apiGroups: ["karpenter.sh"]
#         resources: ["nodepools", "nodepools/status"]
#         verbs: ["update", "patch"]
#       - apiGroups: [""]
#         resources: ["events"]
#         verbs: ["create", "patch"]
#       - apiGroups: [""]
#         resources: ["nodes"]
#         verbs: ["patch", "delete", "update"]
#       - apiGroups: [""]
#         resources: ["pods/eviction"]
#         verbs: ["create"]
#       - apiGroups: [""]
#         resources: ["pods"]
#         verbs: ["delete"]
#       - apiGroups: ["apiextensions.k8s.io"]
#         resources: ["customresourcedefinitions"]
#         verbs: ["update"]
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter6" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: ClusterRole
#     metadata:
#       name: karpenter
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     rules:
#       # Read
#       - apiGroups: ["karpenter.k8s.aws"]
#         resources: ["ec2nodeclasses"]
#         verbs: ["get", "list", "watch"]
#       # Write
#       - apiGroups: ["karpenter.k8s.aws"]
#         resources: ["ec2nodeclasses", "ec2nodeclasses/status"]
#         verbs: ["patch", "update"]
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter7" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: ClusterRoleBinding
#     metadata:
#       name: karpenter-core
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     roleRef:
#       apiGroup: rbac.authorization.k8s.io
#       kind: ClusterRole
#       name: karpenter-core
#     subjects:
#       - kind: ServiceAccount
#         name: karpenter
#         namespace: kube-system
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter8" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: ClusterRoleBinding
#     metadata:
#       name: karpenter
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     roleRef:
#       apiGroup: rbac.authorization.k8s.io
#       kind: ClusterRole
#       name: karpenter
#     subjects:
#       - kind: ServiceAccount
#         name: karpenter
#         namespace: kube-system
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter9" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: Role
#     metadata:
#       name: karpenter
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     rules:
#       # Read
#       - apiGroups: ["coordination.k8s.io"]
#         resources: ["leases"]
#         verbs: ["get", "watch"]
#       - apiGroups: [""]
#         resources: ["configmaps", "secrets"]
#         verbs: ["get", "list", "watch"]
#       # Write
#       - apiGroups: [""]
#         resources: ["secrets"]
#         verbs: ["update"]
#         resourceNames:
#           - "karpenter-cert"
#       - apiGroups: ["coordination.k8s.io"]
#         resources: ["leases"]
#         verbs: ["patch", "update"]
#         resourceNames:
#           - "karpenter-leader-election"
#       # Cannot specify resourceNames on create
#       # https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-resources
#       - apiGroups: ["coordination.k8s.io"]
#         resources: ["leases"]
#         verbs: ["create"]
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter10" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: Role
#     metadata:
#       name: karpenter-dns
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     rules:
#       # Read
#       - apiGroups: [""]
#         resources: ["services"]
#         resourceNames: ["kube-dns"]
#         verbs: ["get"]
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter11" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: Role
#     metadata:
#       name: karpenter-lease
#       namespace: kube-node-lease
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     rules:
#       # Read
#       - apiGroups: ["coordination.k8s.io"]
#         resources: ["leases"]
#         verbs: ["get", "list", "watch"]
#       # Write
#       - apiGroups: ["coordination.k8s.io"]
#         resources: ["leases"]
#         verbs: ["delete"]
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter12" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: RoleBinding
#     metadata:
#       name: karpenter
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     roleRef:
#       apiGroup: rbac.authorization.k8s.io
#       kind: Role
#       name: karpenter
#     subjects:
#       - kind: ServiceAccount
#         name: karpenter
#         namespace: kube-system
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter13" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: RoleBinding
#     metadata:
#       name: karpenter-dns
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     roleRef:
#       apiGroup: rbac.authorization.k8s.io
#       kind: Role
#       name: karpenter-dns
#     subjects:
#       - kind: ServiceAccount
#         name: karpenter
#         namespace: kube-system
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter14" {

#   yaml_body = <<-EOT
#     apiVersion: rbac.authorization.k8s.io/v1
#     kind: RoleBinding
#     metadata:
#       name: karpenter-lease
#       namespace: kube-node-lease
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     roleRef:
#       apiGroup: rbac.authorization.k8s.io
#       kind: Role
#       name: karpenter-lease
#     subjects:
#       - kind: ServiceAccount
#         name: karpenter
#         namespace: kube-system
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter15" {

#   yaml_body = <<-EOT
#     apiVersion: v1
#     kind: Service
#     metadata:
#       name: karpenter
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     spec:
#       type: ClusterIP
#       ports:
#         - name: http-metrics
#           port: 8080
#           targetPort: http-metrics
#           protocol: TCP
#         - name: webhook-metrics
#           port: 8001
#           targetPort: webhook-metrics
#           protocol: TCP
#         - name: https-webhook
#           port: 8443
#           targetPort: https-webhook
#           protocol: TCP
#       selector:
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#   EOT

#   depends_on = [module.eks_cluster]
# }
# resource "kubectl_manifest" "install_karpenter16" {

#   yaml_body = <<-EOT
#     apiVersion: apps/v1
#     kind: Deployment
#     metadata:
#       name: karpenter
#       namespace: kube-system
#       labels:
#         helm.sh/chart: karpenter-1.0.1
#         app.kubernetes.io/name: karpenter
#         app.kubernetes.io/instance: karpenter
#         app.kubernetes.io/version: "1.0.1"
#         app.kubernetes.io/managed-by: Helm
#     spec:
#       replicas: 1
#       revisionHistoryLimit: 10
#       strategy:
#         rollingUpdate:
#           maxUnavailable: 1
#       selector:
#         matchLabels:
#           app.kubernetes.io/name: karpenter
#           app.kubernetes.io/instance: karpenter
#       template:
#         metadata:
#           labels:
#             app.kubernetes.io/name: karpenter
#             app.kubernetes.io/instance: karpenter
#           annotations:
#         spec:
#           serviceAccountName: karpenter
#           securityContext:
#             fsGroup: 65532
#           priorityClassName: "system-cluster-critical"
#           dnsPolicy: ClusterFirst
#           containers:
#             - name: controller
#               securityContext:
#                 runAsUser: 65532
#                 runAsGroup: 65532
#                 runAsNonRoot: true
#                 seccompProfile:
#                   type: RuntimeDefault
#                 allowPrivilegeEscalation: false
#                 capabilities:
#                   drop:
#                     - ALL
#                 readOnlyRootFilesystem: true
#               image: public.ecr.aws/karpenter/controller:1.0.1@sha256:fc54495b35dfeac6459ead173dd8452ca5d572d90e559f09536a494d2795abe6
#               imagePullPolicy: IfNotPresent
#               env:
#                 - name: KUBERNETES_MIN_VERSION
#                   value: "1.30.0-0"
#                 - name: KARPENTER_SERVICE
#                   value: karpenter
#                 - name: WEBHOOK_PORT
#                   value: "8443"
#                 - name: WEBHOOK_METRICS_PORT
#                   value: "8001"
#                 - name: DISABLE_WEBHOOK
#                   value: "false"
#                 - name: LOG_LEVEL
#                   value: "info"
#                 - name: METRICS_PORT
#                   value: "8080"
#                 - name: HEALTH_PROBE_PORT
#                   value: "8081"
#                 - name: SYSTEM_NAMESPACE
#                   valueFrom:
#                     fieldRef:
#                       fieldPath: metadata.namespace
#                 - name: MEMORY_LIMIT
#                   valueFrom:
#                     resourceFieldRef:
#                       containerName: controller
#                       divisor: "0"
#                       resource: limits.memory
#                 - name: FEATURE_GATES
#                   value: "SpotToSpotConsolidation=false"
#                 - name: BATCH_MAX_DURATION
#                   value: "10s"
#                 - name: BATCH_IDLE_DURATION
#                   value: "1s"
#                 - name: CLUSTER_NAME
#                   value: "app-eks-cluster"
#                 - name: VM_MEMORY_OVERHEAD_PERCENT
#                   value: "0.075"
#                 - name: RESERVED_ENIS
#                   value: "0"
#               ports:
#                 - name: http-metrics
#                   containerPort: 8080
#                   protocol: TCP
#                 - name: webhook-metrics
#                   containerPort: 8001
#                   protocol: TCP
#                 - name: https-webhook
#                   containerPort: 8443
#                   protocol: TCP
#                 - name: http
#                   containerPort: 8081
#                   protocol: TCP
#               livenessProbe:
#                 initialDelaySeconds: 30
#                 timeoutSeconds: 30
#                 httpGet:
#                   path: /healthz
#                   port: http
#               readinessProbe:
#                 initialDelaySeconds: 5
#                 timeoutSeconds: 30
#                 httpGet:
#                   path: /readyz
#                   port: http
#               resources:
#                 limits:
#                   cpu: 1
#                   memory: 1Gi
#                 requests:
#                   cpu: 1
#                   memory: 1Gi
#           nodeSelector:
#             kubernetes.io/os: linux
#           # The template below patches the .Values.affinity to add a default label selector where not specificed
#           affinity:
#             nodeAffinity:
#               requiredDuringSchedulingIgnoredDuringExecution:
#                 nodeSelectorTerms:
#                 - matchExpressions:
#                   - key: karpenter.sh/nodepool
#                     operator: DoesNotExist                   
#             podAntiAffinity:
#               requiredDuringSchedulingIgnoredDuringExecution:
#               - labelSelector:
#                   matchLabels:
#                     app.kubernetes.io/instance: karpenter
#                     app.kubernetes.io/name: karpenter
#                 topologyKey: kubernetes.io/hostname
#           # The template below patches the .Values.topologySpreadConstraints to add a default label selector where not specificed
#           topologySpreadConstraints:
#             - labelSelector:
#                 matchLabels:
#                   app.kubernetes.io/instance: karpenter
#                   app.kubernetes.io/name: karpenter
#               maxSkew: 1
#               topologyKey: topology.kubernetes.io/zone
#               whenUnsatisfiable: DoNotSchedule
#           tolerations:
#             - key: CriticalAddonsOnly
#               operator: Exists
#   EOT

#   depends_on = [module.eks_cluster]
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

#   depends_on = [
#     module.eks_cluster,
#     module.eks_managed_node_group,
#   ]
# }

# resource "kubectl_manifest" "install_ec2nodeclass" {
#   yaml_body = <<-EOT
# apiVersion: karpenter.k8s.aws/v1
# kind: EC2NodeClass
# metadata:
#   name: default
# spec:
#   amiFamily: AL2 # Amazon Linux 2
#   role: "KarpenterNodeRole-app-eks-cluster" # replace with your cluster name
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