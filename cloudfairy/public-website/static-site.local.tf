variable "properties" {
  # service_name
  # repo_url
  type = any
}

variable "project" {
  # environment_name
  type = any
}

variable "dependency" {
  # cloud_provider
  # cluster
  type = any
}


locals {
  name           = var.properties.bucketName
  hostname       = lower("${local.name}.localhost")
  container_port = 80
  app_name       = "${local.name}-static"
}

resource "local_file" "static_site" {
  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.name}-static-site.yaml"
  content  = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${local.app_name}
spec:
  selector:
    matchLabels:
      app: ${local.app_name}
  replicas: 1
  template:
    metadata:
      labels:
        app: ${local.app_name}
    spec:
      containers:
      - name: ${local.app_name}
        image: nginx:1.14.2
        ports:
        - containerPort: ${local.container_port}
---
apiVersion: v1
kind: Service
metadata:
  name: ${local.app_name}
  namespace: default
  labels:
    app: ${local.app_name}
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 80
      protocol: TCP
  selector:
    app: ${local.app_name}
---
apiVersion: v1
kind: Service
metadata:
  name: ${local.app_name}
  namespace: default
  labels:
    app: ${local.app_name}
spec:
  type: NodePort
  ports:
    - name: service-port
      port: ${local.container_port}
      targetPort: ${local.container_port}
      protocol: TCP
  selector:
    app: ${local.app_name}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${local.app_name}
  labels:
    app: ${local.app_name}
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  rules:
    - host: ${local.name}.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${local.app_name}
                port:
                  number: ${local.container_port}
EOF
}


output "cfout" {
  value = {
  }
}
