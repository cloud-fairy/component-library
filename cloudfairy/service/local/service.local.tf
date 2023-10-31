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

variable "connector" {
  # cloudfairy_k8_microservice_to_managed_sql : any[]
  type = any
}


locals {
  tags              = var.dependency.base.tags
  dockerfile_path   = var.properties.dockerfile_path
  service_name      = var.properties.service_name
  hostname          = lower("${local.service_name}-${local.tags.Environment}.${local.tags.Project}.local")
  docker_tag        = data.external.env.result["CI_COMMIT_SHA"] != "" ? data.external.env.result["CI_COMMIT_SHA"] : var.project.environment_name
  conn_to_services  = try(var.connector.cloudfairy_service_to_service, [])
  conn_to_storages  = try(var.connector.cloudfairy_service_to_storage, [])
  conn_to_rds       = try(var.connector.cloudfairy_k8_microservice_to_managed_sql, [])
  inject_env_vars   = flatten([local.conn_to_services, local.conn_to_storages, local.conn_to_rds])
  container_port    = var.properties.container_port
  debug_port        = var.properties.debugger_port
  cf_component_name = try(var.properties.local_name, "Cloudfairy Service")
}

data "external" "env" {
  program = ["bash", "${path.module}/env.bash"]
}

resource "local_file" "docker_build" {
  count    = local.dockerfile_path != "" ? 1 : 0
  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.docker-build.ci.sh"
  content  = <<EOF
#!/usr/bin/env sh

set -x
docker build -t ${local.service_name}:${local.docker_tag} ../../${local.dockerfile_path}
docker tag ${local.service_name}:${local.docker_tag} localhost:5001/${local.service_name}:${local.docker_tag}
docker push localhost:5001/${local.service_name}:${local.docker_tag}
  EOF
}

resource "local_file" "deployment" {
  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.deployment.yaml"
  content  = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${var.dependency.cluster.service_account}
  namespace: default
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
          image: k3d-${local.tags.Project}-registry:5000/${local.service_name}:${local.docker_tag}
          ${length(local.inject_env_vars) > 0 ? "env:\n            ${indent(12, yamlencode(local.inject_env_vars))}" : "env: []"}
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
  count = var.properties.isexposed ? 1 : 0

  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.ingress.yaml"
  content  = <<EOF
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: ${local.service_name}-path-prefix
  namespace: default
spec:
  stripPrefix:
    prefixes:
      - /${local.service_name}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${local.service_name}
  labels:
    app: ${local.service_name}
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: web
    traefik.ingress.kubernetes.io/router.middlewares: default-app-svc-path-prefix@kubernetescrd
spec:
  rules:
    - http:
        paths:
          - path: /${local.service_name}
            pathType: Prefix
            backend:
              service:
                name: ${local.service_name}
                port:
                  number: ${local.container_port}
---
EOF
}

resource "local_file" "lifecycle" {
  filename = "${path.module}/../../../../../../../.cloudfairy/ci-cd/${local.service_name}.cloudfairy-lifecycle.sh"
  content  = <<EOF
#!/usr/bin/env sh

set -x
find . -type f -name '${local.service_name}.docker-build.ci.sh' -exec {} ';'
find . -type f -name '${local.service_name}.*.yaml' -exec kubectl apply -f {} ';'
  EOF
}

output "cfout" {
  value = {
    repository_url   = "localhost"
    service_hostname = local.service_name
    service_port     = local.container_port
    env_vars         = local.inject_env_vars
    docker_tag       = local.docker_tag
    hostname         = local.hostname
    debug_port       = local.debug_port
    documentation    = <<EOF
# ${local.cf_component_name} (${local.service_name} Service)

Repository url: localhost

Service Port: ${local.container_port}

Kubernetes DNS Hostname: ${local.service_name}

To rollout a new container:
```bash
docker build -t ${local.service_name}:${local.docker_tag} ../../${local.dockerfile_path}
docker tag ${local.service_name}:${local.docker_tag} localhost:5001/${local.service_name}:${local.docker_tag}
docker push localhost:5001/${local.service_name}:${local.docker_tag}
kubectl rollout restart deployment ${local.service_name}
```
EOF
  }
}
