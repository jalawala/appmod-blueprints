output "prod_cluster_name" {
  description = "EKS Prod Cluster name"
  value       = module.eks_blueprints_prod.eks_cluster_id
}

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints_prod.configure_kubectl
}

output "crossplane_prod_provider_role_arn" {
  description = "Provider role of the Crossplane EKS PROD ServiceAccount for IRSA"
  value       = module.crossplane_prod_provider_role.iam_role_arn
}

output "lb_controller_prod_role_arn" {
  description = "Provider role of the LB controller EKS PROD ServiceAccount for IRSA"
  value       = module.aws_load_balancer_prod_role.iam_role_arn
}
#######

output "prod_aurora_db_secret_arn" {
  description = "The ARN of the Aurora database credentials secret"
  value       = module.aurora.db_secret_arn
}

output "prod_aurora_db_secret_name" {
  description = "The name of the Aurora database credentials secret"
  value       = module.aurora.db_secret_name
}

output "prod_aurora_db_secret_version_id" {
  description = "The version ID of the Aurora database credentials secret"
  value       = module.aurora.db_secret_version_id
}

output "prod_aurora_db_connection_string" {
  description = "The connection string for the Aurora database"
  value       = module.aurora.db_connection_string
  sensitive   = true
}

output "prod_aurora_cluster_endpoint" {
  description = "The cluster endpoint for the Aurora RDS cluster"
  value       = module.aurora.rds_cluster_endpoint
}

output "prod_aurora_cluster_port" {
  description = "The port for the Aurora RDS cluster"
  value       = module.aurora.rds_cluster_port
}

# outputs.tf in the parent directory

output "prod_ec2_instance_id" {
  description = "The ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "prod_ec2_instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = module.ec2.instance_public_ip
}

output "prod_ec2_instance_private_ip" {
  description = "The private IP address of the EC2 instance"
  value       = module.ec2.instance_private_ip
}

output "prod_ec2_security_group_id" {
  description = "The ID of the security group attached to the EC2 instance"
  value       = module.ec2.security_group_id
}

output "prod_ec2_credentials_secret_arn" {
  description = "The ARN of the EC2 credentials secret"
  value       = module.ec2.ec2_credentials_secret_arn
}

output "prod_ec2_credentials_secret_name" {
  description = "The name of the EC2 credentials secret"
  value       = module.ec2.ec2_credentials_secret_name


