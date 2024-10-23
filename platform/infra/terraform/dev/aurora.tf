
 module "aurora" {
    source      = "../database/aurora"
    vpc_id      = var.vpc_id
    subnet_ids  = var.vpc_private_subnets
    vpc_cidr    = var.vpc_cidr
    name_prefix = var.name_prefix
    db_username = var.db_username
    availability_zones = var.availability_zones
  }