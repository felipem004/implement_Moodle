# =============================================================================
# modules/database/variables.tf
# =============================================================================

variable "project_name" {
  type        = string
  description = "Prefixo usado no nome dos recursos de banco de dados."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Lista com os IDs das duas subnets privadas (mínimo 2 AZs) para o subnet group do RDS."
}

variable "rds_security_group_id" {
  type        = string
  description = "ID do Security Group do RDS (aceita 5432 apenas do SG da EC2)."
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados criado na instância RDS."
}

variable "db_username" {
  type        = string
  sensitive   = true
  description = "Usuário master do banco de dados RDS."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Senha master do banco de dados RDS. Use senha forte. Forneça via terraform.tfvars."
}
