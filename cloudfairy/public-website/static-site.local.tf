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
  name              = var.properties.bucketName
  env_name          = var.project.environment_name
  hostname          = lower("${local.name}.localhost")
  container_port    = 80
  app_name          = "${local.name}-static"
  cf_component_name = try(var.properties.local_name, "Cloudfairy Service")
  monorepo_path     = try(var.properties.monorepo_path, "")
  ci_cd_path        = try(var.project.ci_cd_path, "${path.module}/../../../../../../../.cloudfairy.build/ci-cd/${local.env_name}")
}

resource "local_file" "static_site" {
  filename = "${local.ci_cd_path}/${local.name}-static-site.yaml"
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
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  ingressClassName: traefik
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
    documentation = <<EOF
# ${local.cf_component_name} (Static website)
Hostname: ${local.name}.localhost:8080

Create the static website serving on local cloud:
```sh
cd ${local.monorepo_path != "" ? local.monorepo_path : ".cloudfairy.build/ci-cd/${local.env_name}"}
kubectl apply -f "${local.name}-static-site.yaml"
```

Check the pod's health, wait until ready.
```sh
export POD_NAME=$(kubectl get pods | grep ${local.app_name} | awk '{ print $1}')
kubectl wait --for=condition=Ready pod/$POD_NAME
```


Deploy files to static site on local cloud:
```sh
${local.monorepo_path != "" ? "cd ${local.monorepo_path}" : "cd <artifact_path>"}
export POD_NAME=$(kubectl get pods | grep ${local.app_name} | awk '{ print $1}')
foreach filename in .; do
  kubectl cp $filename $POD_NAME:/usr/share/nginx/html
done
```

EOF
  }
}
