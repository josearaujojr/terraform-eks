# module "kubernetes_addons" {
#   source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.32.1/modules/kubernetes-addons"

#   eks_cluster_id = module.eks_cluster.cluster_id

#   #enable_aws_load_balancer_controller  = true
#   enable_amazon_eks_aws_ebs_csi_driver = true
#   enable_metrics_server                = true
#   enable_kube_prometheus_stack         = true

#   kube_prometheus_stack_helm_config = {
#     name = "kube-prometheus-stack" # (Obrigatório) Nome da release.
#     #repository = "https://prometheus-community.github.io/helm-charts" # (Opcional) URL do repositório onde localizar o chart solicitado.
#     chart     = "kube-prometheus-stack" # (Obrigatório) chart a ser instalado.
#     namespace = "kube-prometheus-stack" # (Opcional) namespace para instalar a release.
#     values     = [<<-EOF
#       defaultRules:
#         create: true
#         rules:
#           etcd: false
#           kubeScheduler: false
#       kubeControllerManager:
#         enabled: false
#       kubeEtcd:
#         enabled: false
#       kubeScheduler:
#         enabled: false
#       prometheus:
#         prometheusSpec:
#           storageSpec:
#             volumeClaimTemplate:
#               spec:
#                 accessModes:
#                 - ReadWriteOnce
#                 resources:
#                   requests:
#                     storage: 20Gi
#                 storageClassName: gp2
#         enabled: true
#         ## Configuration for Prometheus service
#         ##
#         service:
#           annotations: {}
#           labels: {}
#           clusterIP: ""
#           port: 9090
#           ## To be used with a proxy extraContainer port
#           targetPort: 9090
#           ## List of IP addresses at which the Prometheus server service is available
#           ## Ref: https://kubernetes.io/docs/user-guide/services/#external-ips
#           ##
#           externalIPs: []
#           ## Port to expose on each node
#           ## Only used if service.type is 'NodePort'
#           ##
#           nodePort: 30090
#           type: NodePort


#       # Adicionando Grafana Dashboards
#       # Projeto: https://github.com/dotdc/grafana-dashboards-kubernetes
#       # Artigo: https://medium.com/@dotdc/a-set-of-modern-grafana-dashboards-for-kubernetes-4b989c72a4b2

#       grafana:
#         # Provision grafana-dashboards-kubernetes
#         dashboardProviders:
#           dashboardproviders.yaml:
#             apiVersion: 1
#             providers:
#             - name: 'grafana-dashboards-kubernetes'
#               orgId: 1
#               folder: 'Kubernetes'
#               type: file
#               disableDeletion: true
#               editable: true
#               options:
#                 path: /var/lib/grafana/dashboards/grafana-dashboards-kubernetes
#         dashboards:
#           grafana-dashboards-kubernetes:
#             k8s-system-api-server:
#               url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-system-api-server.json
#               token: ''
#             k8s-system-coredns:
#               url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-system-coredns.json
#               token: ''
#             k8s-views-global:
#               url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-global.json
#               token: ''
#             k8s-views-namespaces:
#               url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-namespaces.json
#               token: ''
#             k8s-views-nodes:
#               url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-nodes.json
#               token: ''
#             k8s-views-pods:
#               url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-pods.json
#               token: ''
#         sidecar:
#           dashboards:
#             enabled: true
#             defaultFolderName: "General"
#             label: grafana_dashboard
#             labelValue: "1"
#             folderAnnotation: grafana_folder
#             searchNamespace: ALL
#             provider:
#               foldersFromFilesStructure: true
#         grafana:
#           enabled: true
#           datasources:
#             datasources.yaml:
#               apiVersion: 1
#               datasources:
#               - name: Loki
#                 type: loki
#                 url: http://loki:3100
#                 access: proxy
#                 isDefault: false
#     EOF
#     ]
#   }

#   depends_on = [
#     module.eks_cluster
#   ]
# }

# resource "kubectl_manifest" "grafana_ingress" {
#   depends_on = [module.eks_cluster]

#   yaml_body = <<-YAML
#     apiVersion: networking.k8s.io/v1
#     kind: Ingress
#     metadata:
#       name: grafana-ingress
#       namespace: kube-prometheus-stack
#       annotations:
#         nginx.ingress.kubernetes.io/ssl-redirect: "false"
#         nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
#     spec:
#       ingressClassName: nginx
#       rules:
#       - http:
#           paths:
#           - path: /
#             pathType: Prefix
#             backend:
#               service:
#                 name: kube-prometheus-stack-grafana
#                 port:
#                   number: 80
#   YAML
# }

# resource "kubectl_manifest" "prometheus_ingress" {
#   depends_on = [module.eks_cluster]

#   yaml_body = <<-YAML
#     apiVersion: networking.k8s.io/v1
#     kind: Ingress
#     metadata:
#       name: prometheus-ingress
#       namespace: kube-prometheus-stack
#       annotations:
#         nginx.ingress.kubernetes.io/ssl-redirect: "false"
#         nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
#         nginx.ingress.kubernetes.io/rewrite-target: /$2
#     spec:
#       ingressClassName: nginx
#       rules:
#       - http:
#           paths:
#           - path: /prometheus(/|$)(.*)
#             pathType: Prefix
#             backend:
#               service:
#                 name: kube-prometheus-stack-prometheus
#                 port:
#                   number: 9090
#   YAML
# }