variable "properties" {
  # service_name
  # repo_url
  type                 = any
}

variable "project" {
  # environment_name
  type                 = any
}

variable "dependency" {
  # cloud_provider
  # cluster
  type                 = any
}

variable "connector" {
  # cloudfairy_k8_microservice_to_managed_sql : any[]
  type                 = any
}

terraform {
  required_providers {
    external           = {
      source           = "hashicorp/external"
      version          = "2.3.1"
    }
  }
}

locals {

  tags                 = {
    Terraform          = "true"
    Environment        = var.project.environment_name
    Project            = var.project.project_name
    ProjectID          = var.dependency.cloud_provider.projectId
  }

  service_name         = var.properties.service_name
  dockerhub_image      = var.properties.dockerhub_image
  container_port       = var.properties.container_port
  conn_to_services     = try(var.connector.cloudfairy_service_to_service, [])
  inject_env_vars_kv   = toset(var.properties.env_vars)
  # ["FOO=bar", "BAZ=foo"]
  # { name = "FOO" value="bar" },
  # { name = "BAZ" value="foo" },
}

resource "null_resource" "env_vars" {
  for_each = toset(local.inject_env_vars_kv)
  triggers = {
    name = split("=", each.value)[0]
    value = split("=", each.value)[1]
  }
}

resource "null_resource" "env_vars_yaml" {
  triggers = {
    value = <<EOF
          ${length(null_resource.env_vars) > 0 ? "${indent(12, yamlencode(null_resource.env_vars))}" : "[]" }
EOF
  }
}


resource "local_file" "deployment" {
  filename             = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.deployment.yaml"
  content              = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${var.dependency.cluster.service_account}
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${var.dependency.cluster.irsa_role_arn}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${local.service_name}
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${local.service_name}
  template:
    metadata:
      labels:
        app: ${local.service_name}
    spec:
      serviceAccountName: ${var.dependency.cluster.service_account}
      containers:
        - name: ${local.service_name}
          image: ${local.dockerhub_image}
          imagePullPolicy: Always
          ports:
            - containerPort: ${local.container_port}
              protocol: TCP
          resources:
            limits:
              memory: "1Gi"
              cpu: "500m"
EOF
#          env: ${[for i in null_resource.env_vars_yaml : toset(i.triggers)]}
}

resource "local_file" "service" {
  filename             = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.service.yaml"
  content              = <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${local.service_name}
  namespace: default
  labels:
    app: ${local.service_name}
spec:
  type: ClusterIP
  ports:
    - port: ${local.container_port}
      targetPort: ${local.container_port}
      protocol: TCP
  selector:
    app: ${local.service_name}
EOF
}

resource "local_file" "ingress" {
  count         = var.properties.isexposed ? 1 : 0
  
  filename      = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.ingress.yaml"
  content       = <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${local.service_name}
  namespace: default
  labels:
    app: ${local.service_name}
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": ${local.container_port}},{"HTTPS": 443}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    external-dns.alpha.kubernetes.io/hostname: ${local.service_name}.${local.tags.Project}.tikalk.dev
    alb.ingress.kubernetes.io/inbound-cidrs: "0.0.0.0/0, ::/0"
    alb.ingress.kubernetes.io/certificate-arn: ${var.dependency.certificate.arn}
spec:
  ingressClassName: alb
  rules:
    - host: ${local.service_name}.${local.tags.Project}.tikalk.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${local.service_name}
                port:
                  number: ${local.container_port}
  EOF
}

resource "local_file" "lifecycle" {
  filename             = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.cloudfairy-lifecycle.sh"
  content              = <<EOF
#!/usr/bin/env sh

set -x
find . -type f -name '${local.service_name}.*.yaml' -exec kubectl apply -f {} ';'
  EOF
}

output "cfout" {
  value = {
    service_hostname   = local.service_name
    service_port       = local.container_port
    env_vars           = null_resource.env_vars
  }
}