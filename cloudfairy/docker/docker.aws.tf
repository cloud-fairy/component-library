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
  tags                 = var.dependency.base.tags

  zone_name            = var.dependency.cloud_provider.hosted_zone
  hostname             = lower("${local.service_name}-${local.tags.Environment}.${local.tags.Project}.${local.zone_name}")
  service_name         = var.properties.service_name
  dockerhub_image      = var.properties.dockerhub_image
  container_port       = var.properties.container_port
  conn_to_services     = try(var.connector.cloudfairy_service_to_dockerhub, [])

  inject_env_vars_kv   = var.properties.env_vars != "" ? try(toset(var.properties.env_vars), toset([var.properties.env_vars])) : []
  env_vars             = flatten([
                            for element in local.inject_env_vars_kv : {
                              name             = split("=", element)[0]
                              value            = split("=", element)[1]
                            }
                          ])
  # ["FOO=bar", "BAZ=foo"]
  # { name = "FOO" value="bar" },
  # { name = "BAZ" value="foo" },
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
          ${length(local.env_vars) > 0 ? "env:\n            ${indent(12, yamlencode(local.env_vars))}" : "env: []" }
          imagePullPolicy: Always
          ports:
            - containerPort: ${local.container_port}
              protocol: TCP
          resources:
            limits:
              memory: "1Gi"
              cpu: "500m"
EOF
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
    alb.ingress.kubernetes.io/actions.ssl-redirect: |-
      {
        "Type": "redirect",
        "RedirectConfig": {
          "Protocol": "HTTPS",
          "Port": "443",
          "StatusCode": "HTTP_301"
        }
      }
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/ip-address-type: ipv4
    alb.ingress.kubernetes.io/group.name: ${lower("${local.tags.Project}-${local.tags.Environment}")}
    external-dns.alpha.kubernetes.io/hostname: ${local.hostname}
    alb.ingress.kubernetes.io/certificate-arn: ${var.dependency.certificate.arn}
spec:
  ingressClassName: alb
  rules:
    - host: ${local.hostname}
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
    env_vars           = local.env_vars
    hostname           = local.hostname
  }
}