module "ec2" {
    source      = "../database/ec2"
    vpc_id      = var.vpc_id
    subnet_id   = var.subnet_ids[0]
    vpc_cidr    = var.vpc_cidr
    name_prefix = var.name_prefix
    key_name    = var.key_name
  }