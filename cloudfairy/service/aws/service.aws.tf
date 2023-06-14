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
    external = {
      source = "hashicorp/external"
      version = "2.3.1"
    }
  }
}

locals {
  tags = {
    Terraform          = "true"
    Environment        = var.project.environment_name
    Project            = var.project.project_name
    ProjectID          = var.dependency.cloud_provider.projectId
  }
  zone_name            = var.dependency.cloud_provider.hosted_zone
  hostname             = lower("${local.service_name}-${local.tags.Environment}.${local.tags.Project}.${local.zone_name}")
  docker_tag           = data.external.env.result["CI_COMMIT_SHA"] != "" ? data.external.env.result["CI_COMMIT_SHA"] : var.project.environment_name
  ecr_url              = aws_ecr_repository.docker.repository_url
  ecr_name             = "${local.service_name}-${local.tags.Project}-${local.tags.Environment}-${lower(local.tags.ProjectID)}"
  service_name         = var.properties.service_name
  dockerfile_path      = var.properties.dockerfile_path
  container_port       = var.properties.container_port
  debug_port           = var.properties.debugger_port
  conn_to_services     = try(var.connector.cloudfairy_service_to_service, [])
  conn_to_storages     = try(var.connector.cloudfairy_service_to_storage, [])
  conn_to_rds          = try(var.connector.cloudfairy_k8_microservice_to_managed_sql, [])
  inject_env_vars      = flatten([local.conn_to_services, local.conn_to_storages, local.conn_to_rds])
  cf_component_name    = try(var.properties.local_name, "Cloudfairy Service")
}

# Run the script to get the environment variables of interest.
# This is a data source, so it will run at plan time.
data "external" "env" {
  program              = ["bash", "${path.module}/env.bash"]
}

resource "aws_ecr_repository" "docker" {
  name                 = local.ecr_name
  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {
    scan_on_push       = true
  }
  tags                 = local.tags
}

resource "local_file" "docker_build" {
  count                = local.dockerfile_path != "" ? 1 : 0
  filename             = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.docker-build.ci.sh"
  content              = <<EOF
#!/usr/bin/env sh

set -x
aws ecr get-login-password --region ${var.dependency.cloud_provider.region} | docker login --username AWS --password-stdin ${local.ecr_url}
docker build -t ${local.service_name}:${local.docker_tag} ../../${local.dockerfile_path}
docker tag ${local.service_name}:${local.docker_tag} ${local.ecr_url}:${local.docker_tag}
docker push ${local.ecr_url}:${local.docker_tag}
  EOF
}

resource "local_file" "deployment" {
  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.deployment.yaml"
  content = <<EOF
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
          image: ${local.ecr_url}:${local.docker_tag}
          ${length(local.inject_env_vars) > 0 ? "env:\n            ${indent(12, yamlencode(local.inject_env_vars))}" : "env: []" }
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
  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.service.yaml"
  content = <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${local.service_name}
  namespace: default
  labels:
    app: ${local.service_name}
spec:
  type: NodePort
  ports:
    - name: service-port
      port: ${local.container_port}
      targetPort: ${local.container_port}
      protocol: TCP
${local.debug_port != "" ? <<DEBUG_PORT
    - name: debug-port
      port: ${local.debug_port}
      targetPort: ${local.debug_port}
      protocol: TCP   
DEBUG_PORT
: ""}
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
    alb.ingress.kubernetes.io/certificate-arn: ${var.dependency.certificate.arn}
    external-dns.alpha.kubernetes.io/hostname: ${local.hostname}
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
find . -type f -name '${local.service_name}.docker-build.ci.sh' -exec {} ';'
find . -type f -name '${local.service_name}.*.yaml' -exec kubectl apply -f {} ';'
  EOF
}

output "cfout" {
  value = {
    repository_url     = local.ecr_url
    service_hostname   = local.service_name
    service_port       = local.container_port
    env_vars           = local.inject_env_vars
    docker_tag         = local.docker_tag
    hostname           = local.hostname
    debug_port         = local.debug_port
    documentation      = <<EOF
# ${local.cf_component_name} (${local.service_name} Service)

Repository url: ${local.ecr_url}

Service Port: ${local.container_port}

Kubernetes DNS Hostname: ${local.service_name}

To push a new container:
```bash
aws ecr get-login-password --region ${var.dependency.cloud_provider.region} | docker login --username AWS --password-stdin ${local.ecr_url}
docker build -t ${local.ecr_url}:${local.docker_tag} ${local.dockerfile_path}
docker push ${local.ecr_url}:${local.docker_tag}
kubectl rollout restart deployment ${local.service_name}
```
EOF
  }
}
