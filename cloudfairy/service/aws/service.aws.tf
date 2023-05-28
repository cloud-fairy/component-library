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
  docker_tag           = try(data.external.env.result["CI_COMMIT_SHA"], var.project.environment_name)
  ecr_url              = aws_ecr_repository.docker.repository_url
  service_name         = var.properties.service_name
  dockerfile_path      = var.properties.repo_url
}

# Run the script to get the environment variables of interest.
# This is a data source, so it will run at plan time.
data "external" "env" {
  program = ["bash", "${path.module}/env.bash"]
}

resource "aws_ecr_repository" "docker" {
  name                 = local.service_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push       = true
  }
  tags                 = local.tags
}

resource "local_file" "docker_build" {
  filename             = "${path.module}/../../../../../../../${local.service_name}.docker-build.ci.sh"
  content              = <<EOF
#!/usr/bin/env sh

set -x
aws ecr get-login-password --region ${var.dependency.cloud_provider.region} | docker login --username AWS --password-stdin ${local.ecr_url}
docker build -t ${local.service_name}:${local.docker_tag} ${local.dockerfile_path}
docker tag ${local.service_name}:${local.docker_tag} ${local.ecr_url}:${local.docker_tag}
docker push ${local.ecr_url}:${local.docker_tag}
  EOF
}

resource "local_file" "deployment" {
  filename = "${path.module}/../../../../../../../${local.service_name}.deployment.yaml"
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
          imagePullPolicy: Always
          ports:
            - containerPort: 80
              protocol: TCP
EOF
}

resource "local_file" "ingress" {
  count = var.properties.isexposed ? 1 : 0
  
  filename = "${path.module}/../../../../../../../${local.service_name}.ingress.yaml"
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
    - port: 80
      targetPort: 80
      protocol: TCP
  selector:
    app: ${local.service_name}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${local.service_name}
  namespace: default
  labels:
    app: ${local.service_name}
  annotations:
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    external-dns.alpha.kubernetes.io/hostname: ${local.service_name}.tikalk.dev
spec:
  ingressClassName: alb
  rules:
    - host: ${local.service_name}.tikalk.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${local.service_name}
                port:
                  number: 80
  EOF
}

resource "local_file" "lifecycle" {
  filename             = "${path.module}/../../../../../../../${local.service_name}.cloudfairy-lifecycle.sh"
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
  }
}