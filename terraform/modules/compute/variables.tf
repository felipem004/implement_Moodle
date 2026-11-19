# =============================================================================
# modules/compute/variables.tf
# =============================================================================

variable "project_name" {
  type        = string
  description = "Prefixo usado no nome dos recursos de compute."
}

variable "public_subnet_id" {
  type        = string
  description = "ID da subnet pública onde a EC2 será alocada."
}

variable "ec2_security_group_id" {
  type        = string
  description = "ID do Security Group da EC2 (portas 80 e 22)."
}

variable "ec2_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Tipo da instância EC2. t3.medium oferece 2 vCPUs e 4 GB RAM."
}

variable "ec2_public_key" {
  type        = string
  sensitive   = true
  description = "Conteúdo da chave pública no formato OpenSSH (ex: ssh-rsa AAAA...). Usada para criar o aws_key_pair."
}

variable "rds_endpoint" {
  type        = string
  description = "Endpoint do RDS PostgreSQL (host:porta) injetado no user_data.sh via templatefile()."
}

variable "rds_port" {
  type        = number
  description = "Porta do RDS PostgreSQL (5432)."
}

variable "db_name" {
  type        = string
  description = "Nome do banco de dados — injetado no user_data.sh."
}

variable "db_username" {
  type        = string
  sensitive   = true
  description = "Usuário do banco de dados — injetado no user_data.sh."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Senha do banco de dados — injetada no user_data.sh. Nunca exposta em logs."
}
