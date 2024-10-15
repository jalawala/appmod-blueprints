variable "vpc_name" {
  description = "Name of the existing VPC (leave empty to create a new VPC)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (used when creating a new VPC)"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

data "aws_vpc" "existing_vpc" {
  count = var.vpc_name != "" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "existing_subnets" {
  count = var.vpc_name != "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc[0].id]
  }
}

resource "aws_vpc" "new_vpc" {
  count      = var.vpc_name == "" ? 1 : 0
  cidr_block = var.vpc_cidr
  
  tags = {
    Name = "${var.name_prefix}mod-engg-wksp-vpc"
  }
}

data "aws_subnet" "existing_subnet_details" {
  count = var.vpc_name != "" ? length(data.aws_subnets.existing_subnets[0].ids) : 0
  id    = data.aws_subnets.existing_subnets[0].ids[count.index]
}

locals {
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  existing_azs       = var.vpc_name != "" ? distinct([for s in data.aws_subnet.existing_subnet_details : s.availability_zone]) : []
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "new_subnets" {
  count             = var.vpc_name == "" ? 2 : 0
  vpc_id            = aws_vpc.new_vpc[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.name_prefix}mod-engg-wksp-subnet-${count.index}"
  }
}

locals {
  vpc_id     = var.vpc_name != "" ? data.aws_vpc.existing_vpc[0].id : aws_vpc.new_vpc[0].id
  subnet_ids = var.vpc_name != "" ? data.aws_subnets.existing_subnets[0].ids : aws_subnet.new_subnets[*].id
  vpc_cidr   = var.vpc_name != "" ? data.aws_vpc.existing_vpc[0].cidr_block : var.vpc_cidr
}

output "vpc_id" {
  value = local.vpc_id
}

output "subnet_ids" {
  value = local.subnet_ids
}

output "vpc_cidr" {
  value = local.vpc_cidr
}

output "availability_zones" {
  value = var.vpc_name == "" ? aws_subnet.new_subnets[*].availability_zone : local.existing_azs
}
