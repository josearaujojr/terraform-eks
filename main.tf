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

module "eks_efs_logs" {
  source              = "./modules/efs"
  project_name        = var.project_name
  tags                = local.tags
  cluster_id          = var.cluster_name
  eks_vpc_id          = module.eks_network.eks_vpc
  subnet_priv_1a      = module.eks_network.subnet_priv_1a
  subnet_priv_1b      = module.eks_network.subnet_priv_1b
  eks_cluster_sg_id   = module.eks_cluster.eks_cluster_security_group
  eks_cluster_sg_rule = module.eks_cluster.eks_cluster_sg_rule
  oidc_issuer_url     = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  depends_on          = [module.eks_cluster]
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

resource "helm_release" "external_secret_operator" {
  name       = "external-secret-operator"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "default"
}

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

########################## SONARQUBE
resource "kubernetes_namespace" "sonarqube" {
  metadata {
    name = "sonarqube"
  }
}

resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "sonarqube"
  #version    = "11.0.0"
  namespace  = kubernetes_namespace.sonarqube.metadata[0].name

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "postgresql.enabled"
    value = "true"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }
}