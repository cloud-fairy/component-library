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

# variable "environment_variables" {
#   type = any
# }

locals {
  tags = {
    Terraform          = "true"
    Environment        = var.project.environment_name
    Project            = var.project.project_name
    ProjectID          = var.dependency.cloud_provider.projectId
  }
  docker_tag           = var.project.environment_name #try(var.environment_variables.CI_COMMIT_SHA, var.project.environment_name)
  ecr_url              = aws_ecr_repository.docker.repository_url
  service_name         = var.properties.service_name
  dockerfile_path      = var.properties.repo_url
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
docker tag ${local.service_name}:${local.docker_tag} ${local.ecr_url}:dev
docker push ${local.ecr_url}:dev
  EOF
}

resource "local_file" "deployment" {
  filename = "${path.module}/../../../../../../../${local.service_name}.deployment.yaml"
  content = <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${local.service_name}
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
          image: "${local.ecr_url}:${local.docker_tag}"
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
EOF
}

resource "local_file" "lifecycle" {
  filename             = "${path.module}/../../../../../../../${local.service_name}.cloudfairy-lifecycle.sh"
  content              = <<EOF
#!/usr/bin/env sh

find . -type f -name '*.ci.sh' -exec {} +
find . -type f -name '*.deployment.yaml' -exec kubectl apply -f {} +
  EOF
}

output "cfout" {
  value = {
    repository_url     = local.ecr_url
  }
}