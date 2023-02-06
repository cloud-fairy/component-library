# Cloudfairy 
Cloudfairy is a  tool that helps you genarate and automate your cloud infrastructure resources.

## Requirements
- Node.js 16+

## Features

- Deploy and manage cloud resources

- Easily switch between different cloud providers
- Supports multiple cloud platforms including AWS, GCP, and Azure
- Provides real-time updates on resource deployment
- User-friendly  interface by UI and cli.


## Installation

To start using Cloudfairy CLI, run the following command:

```
update/install npm
# npm install -g npm@9.2.0

install cloudfairy
# npm i -g @cloudfairy/cli
```   

## usage

```
fairy init
```
define default library.

fairy project|p [options] [command] :
```

Options:
  -h, --help                                                               display help for command

Commands:
  init [project-name]                                                      Initialize an empty infrastructure
  info|i [options]                                                         Show infrastructure information
  remove-component|rmc <name>
  describe-component|describe <name>
  rename-component|ren <name> <new-name>
  connect-component|connect <from-component-id> <to-component-id>
  disconnect-component|disc <from-component-id> <to-component-id>
  configure-component-property|c [options] [component] [property] [value]
  set-cloud-provider|scp [cloud-provider]
  deploy
  add-component|add [options] [component-kind] [name]
  disconnect-component|disc <from-component-id> <to-component-id>
  help [command]
```
fairy library|l [options] [command] :
```
Manage component libraries

Options:
  -h, --help          display help for command

Commands:
  add <name> <path>
  list|ls
  info <name>
  update
  remove|rm <name>
  set-default <name>
  help [command]      display help for command
```

Now lets have a look how to adjust  [eks bluprint module](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main/examples/eks-cluster-with-new-vpc)
 to be applied by cloudfairy tool :

![Screenshot](./tutorial/screenshot.png)

as we can see the module has inputs configured in variable.tf file and outpusts configured in outputs.tf

project- shared properties.
```
variable properties {
  type = any
}

```
properties- inputs of the module - inserted by user or as defaults. 
```
variable properties {
  type = any
}

```
cfout-  object of mapped variable presenting the ouput of the module. 
```

output "cfout" {
  value = {
    name                   = module.eks.name
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
  sensitive = true
}
```

dependency - maped variables injected from "cfout" object of the depend module 
```
variable "dependency" {
  type = any
}
```