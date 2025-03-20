# resource "kubectl_manifest" "install_nginx" {
#   yaml_body = <<-EOT
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: nginx
#   namespace: default
# spec:
#   replicas: 1
#   selector:
#     matchLabels:
#       app: nginx
#   template:
#     metadata:
#       labels:
#         app: nginx
#     spec:
#       containers:
#         - name: nginx
#           image: nginx
#           ports:
#             - containerPort: 80
#           resources:
#             limits:
#               memory: "256Mi"
#               cpu: "256m"
#             requests:
#               memory: "128Mi"
#               cpu: "128m"
#   EOT

#   depends_on = [module.eks_cluster]
# }

# resource "kubectl_manifest" "nginx_service" {
#   yaml_body = <<-EOT
# apiVersion: v1
# kind: Service
# metadata:
#   name: nginx-service
#   namespace: default
# spec:
#   selector:
#     app: nginx
#   ports:
#     - protocol: TCP
#       port: 80
#       targetPort: 80
#   type: ClusterIP
#   EOT

#   depends_on = [kubectl_manifest.install_nginx]
# }

# resource "kubectl_manifest" "nginx_ingress" {
#   yaml_body = <<-EOT
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: nginx-ingress
#   namespace: default
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     nginx.ingress.kubernetes.io/rewrite-target: /
# spec:
#   rules:
#     - http:
#         paths:
#           - path: /
#             pathType: Prefix
#             backend:
#               service:
#                 name: nginx-service
#                 port:
#                   number: 80
#   EOT

#   depends_on = [kubectl_manifest.nginx_service]
# }