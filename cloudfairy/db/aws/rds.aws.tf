locals {
  port            =  var.properties.engine == "oracle" ? 1521 : var.properties.engine == "postgresql" ? 5432 : 3306
  engine_version  = {
    mysql         = var.mysql_version
    postgres      = var.postgresql_version
    mariadb       = var.mariadb_version
  }
  major_version   = join("", regex("^(\\d){1,2}(\\.)(\\d){1,2}", local.engine_version[var.properties.engine]))
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.dependency.subnet.vpc_id]
  }
  filter {
    name   = "tag:Environment"
    values = [var.project.environment_name]
  }
  filter {
    name   = "tag:Project"
    values = [var.project.project_name]
  }
  filter {
    name   = "tag:Component"
    values = ["subnet"]
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.6.0"

  identifier        = var.properties.name

  engine            = var.properties.engine
  engine_version    = local.engine_version[var.properties.engine]
  instance_class    = var.instance_class
  allocated_storage = 5

  db_name  = var.properties.name
  username = "admin"
  port     = local.port

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [var.dependency.sg.security_group_id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # Enhanced Monitoring - see example for details on how to create the role
  # by yourself, in case you don't want to create it automatically
  monitoring_interval = "30"
  monitoring_role_name = "MyRDSMonitoringRole"
  create_monitoring_role = true

  tags = {
    Terraform   = "true"
    Environment = var.project.environment_name
    Project     = var.project.project_name
  }

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = data.aws_subnets.private.ids

  # DB parameter group
  family = "${var.properties.engine}${local.major_version}"

  # DB option group
  major_engine_version = local.major_version

  # Database Deletion Protection
  deletion_protection = true

  parameters = [
    {
      name = "character_set_client"
      value = "utf8mb4"
    },
    {
      name = "character_set_server"
      value = "utf8mb4"
    }
  ]
}

output "cfout" {
  value = {
    name              = var.properties.name
    engine            = module.db.db_instance_engine
    endpoint          = module.db.db_instance_endpoint
    db_instance_arn   = module.db.db_instance_arn
    monitoring_role   = module.db.enhanced_monitoring_iam_role_name
  }
}