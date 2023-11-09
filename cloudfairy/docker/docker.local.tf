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

provider "external" {}


locals {
  tags = var.dependency.base.tags

  service_name = var.properties.service_name
  env_name     = var.project.environment_name
  ci_cd_path   = try(var.project.ci_cd_path, "${path.module}/../../../../../../../.cloudfairy.build/ci-cd/${local.env_name}")

  hostname         = lower("${local.service_name}")
  dockerhub_image  = var.properties.dockerhub_image
  container_port   = var.properties.container_port
  conn_to_services = try(var.connector.cloudfairy_service_to_dockerhub, [])

  inject_env_vars_kv = var.properties.env_vars != "" ? try(toset(var.properties.env_vars), toset([var.properties.env_vars])) : []
  env_vars = flatten([
    for element in local.inject_env_vars_kv : {
      name  = split("=", element)[0]
      value = split("=", element)[1]
    }
  ])
  # ["FOO=bar", "BAZ=foo"]
  # { name = "FOO" value="bar" },
  # { name = "BAZ" value="foo" },
}

resource "local_file" "deployment" {
  filename = "${local.ci_cd_path}/${local.service_name}.deployment.yaml"
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
          image: ${local.dockerhub_image}
          ${length(local.env_vars) > 0 ? "env:\n            ${indent(12, yamlencode(local.env_vars))}" : "env: []"}
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
  filename = "${local.ci_cd_path}/${local.service_name}.service.yaml"
  content  = <<EOF
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
  count    = var.properties.isexposed ? 1 : 0
  filename = "${local.ci_cd_path}/${local.service_name}.ingress.yaml"
  content  = <<EOF
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
spec:
  rules:
    - host: ${local.service_name}.localhost
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

output "cfout" {
  value = {
    service_hostname = local.service_name
    service_port     = local.container_port
    env_vars         = local.env_vars
    hostname         = local.hostname
    documentation    = <<EOF
# ${local.service_name} (Service from dockerhub)

${var.properties.isexposed ? "Hostname: ${local.hostname}.localhost:8080\n" : ""}
Deploy the service on local cloud

```sh
cd ${local.ci_cd_path}
find . -type f -name '${local.service_name}.*.yaml' -exec kubectl apply -f {} ';'
```

Check the pod's health, wait until ready.
```sh
export POD_NAME=$(kubectl get pods | grep ${local.service_name} | awk '{ print $1}')
kubectl wait --for=condition=Ready pod/$POD_NAME
```

EOF
  }
}
