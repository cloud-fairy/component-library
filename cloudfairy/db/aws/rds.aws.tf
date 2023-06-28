locals {
  engine                              =  var.properties.engine
  port                                =  local.engine == "postgres" ? 5432 : 3306
  subnets_count                       =  length(split(",", (jsonencode(data.aws_subnets.public.*.ids[0][*]))))
  create_db                           =  local.subnets_count > 1 ? true : false    # Two subnets required to create RDS Subnet group
  db_user                             =  "${var.properties.name}_admin"
  engine_version                      = {
    mysql                             =  var.mysql_version
    postgres                          =  var.postgresql_version
    mariadb                           =  var.mariadb_version
  }
  tags                                =  var.dependency.base.tags 

  major_version   = join("", local.engine != "postgres" ? [
                      join("", regex("^(\\d{1,2})(\\.)(\\d{1,2})", local.engine_version[local.engine])) ] :  [            
                      join("", regex("^(\\d{1,2})(?:\\.)", local.engine_version[local.engine]))  ]  )           
}

data "aws_subnets" "public" {
  filter {
    name                              = "vpc-id"
    values                            = [var.dependency.network.id]
  }
  filter {
    name                              = "tag:Environment"
    values                            = [local.tags.Environment]
  }
  filter {
    name                              = "tag:Project"
    values                            = [local.tags.Project]
  }
  filter {
    name                              = "tag:ProjectID"
    values                            = [local.tags.ProjectID]
  }
  filter {
    name                              = "tag:type"
    values                            = ["Public"]
  }
}

module "db" {
  source                              = "terraform-aws-modules/rds/aws"
  version                             = "5.9.0"
  create_db_instance                  = local.create_db

  identifier                          = var.properties.name

  engine                              = local.engine
  engine_version                      = local.engine_version[local.engine]
  instance_class                      = local.engine != "aurora-mysql" ? var.deafult_instance_class : var.aurora_instance_class
  allocated_storage                   = var.properties.size
  publicly_accessible                 = true
      
  db_name                             = var.properties.name
  username                            = local.db_user
  port                                = local.port
  password                            = random_string.psw.result
  create_random_password              = false

  iam_database_authentication_enabled = true

  vpc_security_group_ids              = [var.dependency.sg.security_group_id]

  maintenance_window                  = "Mon:00:00-Mon:03:00"
  backup_window                       = "03:00-06:00"

  # Create monitoring role only if DB can be created
  create_monitoring_role              = false

  tags                                = local.tags

  # Create DB subnet group only if DB can be created
  create_db_subnet_group              = local.create_db
  subnet_ids                          = data.aws_subnets.public.ids

  # DB parameter group
  family                              = "${local.engine}${local.major_version}"

  # DB option group
  major_engine_version                =  local.major_version

  # Database Deletion Protection
  deletion_protection                 = false
}

resource "random_string" "psw" {
  length                              = 16
  special                             = false
}

output "cfout" {
  value = {
    name                              = var.properties.name
    engine                            = module.db.db_instance_engine
    endpoint                          = module.db.db_instance_endpoint
    uid                               = local.db_user
    psw                               = random_string.psw.result
    port                              = module.db.db_instance_port
    db_arn                            = module.db.db_instance_arn
    error                             = local.create_db == false ? "Must have at least two subnets in two AZs in order to create subnet group" : ""
  }
  
}