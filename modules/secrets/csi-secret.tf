# install do Secrets Store CSI Driver usando o Helm Release
resource "helm_release" "csi_secrets_store" {
  name       = "csi-secrets-store"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.3.3"  # version do chart

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

resource "kubectl_manifest" "csi_secret_0" {
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


resource "kubectl_manifest" "csi_secret_1" {
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

resource "kubectl_manifest" "csi_secret_2" {
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

resource "kubectl_manifest" "csi_secret_3" {
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

resource "kubectl_manifest" "csi_secret_4" {
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

resource "kubectl_manifest" "csi_secret_5" {
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

# Inclusão de permissões globais em todos os namespaces
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