provider "aws" {
    region = "us-east-1"
    alias  = "ecr"
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

module "eks_network" {
  source       = "./modules/network"
  cidr_block   = var.cidr_block
  project_name = var.project_name
  tags         = merge(local.tags, local.karpenter_tags)
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
  vpc_id            = module.eks_network.eks_vpc
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  cluster_id        = module.eks_cluster.cluster_id
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

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.20.0"

  cluster_name = module.eks_cluster.cluster_name
  irsa_oidc_provider_arn          = module.eks_cluster.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "aws_iam_policy" "karpenter_policy_additional" {
  name        = "KarpenterAdditionalPolicy"
  description = "Policy for additional permissions required by Karpenter"
  policy      = file("PolicyAdditionalKarpenter.json")  

  depends_on = [ module.karpenter ]
}

resource "aws_iam_role_policy_attachment" "karpenter_additional_policy" {
  role       = module.karpenter.irsa_name
  policy_arn = aws_iam_policy.karpenter_policy_additional.arn

  depends_on = [ module.karpenter ]
}

resource "helm_release" "karpenter" {
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  version    = "1.0.10"
  namespace  = "karpenter"
  chart            = "karpenter"
  create_namespace = true
  wait             = true

  set {
    name  = "settings.clusterName"
    value = "${module.eks_cluster.cluster_name}"
  }

  set {
    name  = "settings.interruptionQueue"
    value = "${module.karpenter.queue_name}"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:${var.aws_partition}:iam::${var.aws_account_id}:role/${module.karpenter.irsa_name}"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  depends_on = [ module.karpenter ]
}

resource "kubectl_manifest" "install_nodepool" {
  yaml_body = <<-EOT
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 dias
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
  EOT

  depends_on = [ helm_release.karpenter ]
}

resource "kubectl_manifest" "install_ec2nodeclass" {
  yaml_body = <<-EOT
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  amiSelectorTerms:
    - alias: al2023@latest
  role: ${module.karpenter.role_name}
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${module.eks_cluster.cluster_name}
  EOT

  depends_on = [ helm_release.karpenter ]
}

module "secret_manager" {
  source          = "./modules/secrets"
  project_name    = var.project_name
  oidc_issuer_url = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  aws_account_id  = var.aws_account_id
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

########################## HELM RELEASE

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  namespace        = "ingress-nginx"
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

########################## EXTERNAL SECRETS OPERATOR

# resource "helm_release" "external_secret_operator" {
#   name       = "external-secret-operator"
#   repository = "https://charts.external-secrets.io"
#   chart      = "external-secrets"
#   namespace  = "default"
# }

########################## CSI SECRET STORE

# install do Secrets Store CSI Driver usando o Helm Release
resource "helm_release" "csi_secrets_store" {
  name       = "csi-secrets-store"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.3.3" # version do chart

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  set {
    name  = "rotationPollInterval"
    value = "10s"
  }

  # values = [
  #   file("${path.module}/values.yaml")  # files de valores, opcional
  # ]
}

resource "kubectl_manifest" "csi_secret_sa" {
  yaml_body = <<-EOT
# https://kubernetes.io/docs/reference/access-authn-authz/rbac
apiVersion: v1
kind: ServiceAccount
metadata:
  name: csi-secrets-store-provider-aws
  namespace: kube-system
  EOT

  depends_on = [module.eks_cluster]
}


resource "kubectl_manifest" "csi_secret_cr" {
  yaml_body = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: csi-secrets-store-provider-aws-cluster-role
rules:
- apiGroups: [""]
  resources: ["serviceaccounts/token"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get"]
  EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "csi_secret_crb" {
  yaml_body = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: csi-secrets-store-provider-aws-cluster-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: csi-secrets-store-provider-aws-cluster-role
subjects:
- kind: ServiceAccount
  name: csi-secrets-store-provider-aws
  namespace: kube-system
  EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "csi_secret_ds" {
  yaml_body = <<-EOT
apiVersion: apps/v1
kind: DaemonSet
metadata:
  namespace: kube-system
  name: csi-secrets-store-provider-aws
  labels:
    app: csi-secrets-store-provider-aws
spec:
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: csi-secrets-store-provider-aws
  template:
    metadata:
      labels:
        app: csi-secrets-store-provider-aws
    spec:
      serviceAccountName: csi-secrets-store-provider-aws
      hostNetwork: false
      containers:
        - name: provider-aws-installer
          image: public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:1.0.r2-72-gfb78a36-2024.05.29.23.03
          imagePullPolicy: Always
          args:
              - --provider-volume=/etc/kubernetes/secrets-store-csi-providers
          resources:
            requests:
              cpu: 50m
              memory: 100Mi
            limits:
              cpu: 50m
              memory: 100Mi
          securityContext:
            privileged: false
            allowPrivilegeEscalation: false
          volumeMounts:
            - mountPath: "/etc/kubernetes/secrets-store-csi-providers"
              name: providervol
            - name: mountpoint-dir
              mountPath: /var/lib/kubelet/pods
              mountPropagation: HostToContainer
      volumes:
        - name: providervol
          hostPath:
            path: "/etc/kubernetes/secrets-store-csi-providers"
        - name: mountpoint-dir
          hostPath:
            path: /var/lib/kubelet/pods
            type: DirectoryOrCreate
      nodeSelector:
        kubernetes.io/os: linux
  EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "csi_secret_cr2" {
  yaml_body = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secrets-store-csi-driver-cluster-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "csi_secret_crb2" {
  yaml_body = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secrets-store-csi-driver-cluster-rolebinding
subjects:
- kind: ServiceAccount
  name: secrets-store-csi-driver
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: secrets-store-csi-driver-cluster-role
  apiGroup: rbac.authorization.k8s.io
EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "csi_secret_clusterrole" {
  yaml_body = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secrets-store-csi-driver-global-clusterrole
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "update", "delete"]
EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "csi_secret_clusterrolebinding" {
  yaml_body = <<-EOT
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secrets-store-csi-driver-global-clusterrolebinding
subjects:
- kind: ServiceAccount
  name: secrets-store-csi-driver
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: secrets-store-csi-driver-global-clusterrole
  apiGroup: rbac.authorization.k8s.io
EOT

  depends_on = [module.eks_cluster]
}

resource "kubectl_manifest" "aws_auth" {
  yaml_body = <<YAML
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: aws-auth
    namespace: kube-system
  data:
    mapRoles: |
      - rolearn: arn:aws:iam::${var.aws_account_id}:role/app-eks-mng-role
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
      - rolearn: arn:aws:iam::${var.aws_account_id}:role/${module.karpenter.role_name}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
  YAML

  depends_on = [module.eks_cluster, module.karpenter]
}