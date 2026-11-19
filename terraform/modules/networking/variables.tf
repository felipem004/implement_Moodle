# =============================================================================
# modules/networking/variables.tf
# =============================================================================

variable "project_name" {
  type        = string
  description = "Prefixo usado no nome de todos os recursos de rede."
}

variable "vpc_cidr" {
  type        = string
  description = "Bloco CIDR da VPC principal."
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR da subnet pública (us-east-1a) onde a EC2 será alocada."
}

variable "private_subnet_cidr_a" {
  type        = string
  description = "CIDR da subnet privada na AZ us-east-1a (para o subnet group do RDS)."
}

variable "private_subnet_cidr_b" {
  type        = string
  description = "CIDR da subnet privada na AZ us-east-1b (segunda AZ obrigatória para o subnet group do RDS)."
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "CIDR autorizado para acesso SSH à EC2 na porta 22."
}
