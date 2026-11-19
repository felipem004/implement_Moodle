# =============================================================================
# variables.tf — Variáveis raiz do projeto
# Os valores são fornecidos via terraform.tfvars (ignorado pelo Git).
# =============================================================================

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Região AWS onde os recursos serão provisionados. O AWS Learn Lab opera em us-east-1."
}

variable "project_name" {
  type        = string
  default     = "moodle-challenge"
  description = "Prefixo usado no nome de todos os recursos AWS para facilitar identificação."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Bloco CIDR da VPC principal."
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR da subnet pública onde a EC2 será alocada (us-east-1a)."
}

variable "private_subnet_cidr_a" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR da subnet privada na AZ us-east-1a (para o subnet group do RDS)."
}

variable "private_subnet_cidr_b" {
  type        = string
  default     = "10.0.3.0/24"
  description = "CIDR da subnet privada na AZ us-east-1b (segunda AZ obrigatória para o subnet group do RDS)."
}

variable "ec2_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Tipo da instância EC2. t3.medium oferece 2 vCPUs e 4 GB RAM, suficiente para o Moodle em carga educacional."
}

variable "ec2_public_key" {
  type        = string
  sensitive   = true
  description = "Conteúdo da chave pública no formato OpenSSH (ex: ssh-rsa AAAA...). Usada para criar o aws_key_pair e acessar a EC2 via SSH. Forneça via terraform.tfvars — nunca commite o valor real."
}

variable "ssh_allowed_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR autorizado para acesso SSH à EC2. AVISO DE SEGURANÇA: o valor padrão 0.0.0.0/0 permite SSH de qualquer origem; restrinja ao seu IP público (ex: 203.0.113.10/32) em produção."
}

variable "db_name" {
  type        = string
  default     = "moodle"
  description = "Nome do banco de dados criado na instância RDS."
}

variable "db_username" {
  type        = string
  sensitive   = true
  description = "Usuário master do banco de dados RDS. Forneça via terraform.tfvars."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Senha master do banco de dados RDS. Use senha forte. Forneça via terraform.tfvars — nunca commite o valor real."
}
