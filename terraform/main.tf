# =============================================================================
# main.tf — Raiz do projeto Terraform
# Instancia os três módulos: networking, database e compute.
# A ordem de dependência é: networking → database → compute.
# =============================================================================

# TODO: Ajuste os valores de vpc_cidr, subnets e ssh_allowed_cidr no terraform.tfvars
# conforme a necessidade do seu ambiente antes de executar terraform apply.

# -----------------------------------------------------------------------------
# Módulo 1: networking
# Cria a VPC, subnets, Internet Gateway, route table e security groups.
# -----------------------------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_cidr_a = var.private_subnet_cidr_a
  private_subnet_cidr_b = var.private_subnet_cidr_b
  ssh_allowed_cidr      = var.ssh_allowed_cidr
}

# -----------------------------------------------------------------------------
# Módulo 2: database
# Cria o subnet group e a instância RDS PostgreSQL 15 nas subnets privadas.
# Depende dos outputs do módulo networking.
# -----------------------------------------------------------------------------
module "database" {
  source = "./modules/database"

  project_name          = var.project_name
  private_subnet_ids    = module.networking.private_subnet_ids
  rds_security_group_id = module.networking.rds_security_group_id
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
}

# -----------------------------------------------------------------------------
# Módulo 3: compute
# Cria o key pair, a instância EC2 e executa o user_data.sh no boot.
# Depende dos outputs de networking (subnet, SG) e database (endpoint do RDS).
# -----------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  project_name          = var.project_name
  public_subnet_id      = module.networking.public_subnet_id
  ec2_security_group_id = module.networking.ec2_security_group_id
  ec2_instance_type     = var.ec2_instance_type
  ec2_public_key        = var.ec2_public_key
  rds_endpoint          = module.database.rds_address
  rds_port              = module.database.rds_port
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
}
