# =============================================================================
# modules/networking/main.tf
# Cria toda a camada de rede: VPC, subnets, IGW, route table e security groups.
#
# Arquitetura provisionada:
#   VPC 10.0.0.0/16
#   ├── Subnet pública  10.0.1.0/24 (us-east-1a) — EC2
#   ├── Subnet privada  10.0.2.0/24 (us-east-1a) — RDS AZ-A
#   └── Subnet privada  10.0.3.0/24 (us-east-1b) — RDS AZ-B (exigida pelo subnet group)
# =============================================================================

# TODO: Adicione tags extras nos recursos abaixo se necessário para identificação no console AWS.

# -----------------------------------------------------------------------------
# VPC principal
# enable_dns_hostnames = true é necessário para que a EC2 receba DNS público.
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Subnet pública — EC2 (us-east-1a)
# map_public_ip_on_launch = true garante que a EC2 receba IP público automático.
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# -----------------------------------------------------------------------------
# Subnet privada AZ-A — RDS (us-east-1a)
# Sem map_public_ip_on_launch: o RDS não recebe IP público.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_a
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "${var.project_name}-private-subnet-a"
  }
}

# -----------------------------------------------------------------------------
# Subnet privada AZ-B — RDS subnet group (us-east-1b)
# O aws_db_subnet_group exige ao menos 2 AZs distintas.
# Não há instância RDS ativa nesta AZ — ela existe apenas para satisfazer
# o requisito do subnet group.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_b
  availability_zone = "${data.aws_region.current.name}b"

  tags = {
    Name = "${var.project_name}-private-subnet-b"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway — permite tráfego entre a VPC e a Internet
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -----------------------------------------------------------------------------
# Route Table pública — direciona 0.0.0.0/0 para o Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associa a route table pública à subnet pública
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Security Group da EC2
# Ingresso: TCP 80 de qualquer origem (Moodle público) e TCP 22 restrito ao CIDR configurado
# Egresso: irrestrito (a EC2 precisa baixar pacotes e conectar ao RDS)
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Permite HTTP (80) de qualquer origem e SSH (22) do CIDR configurado."
  vpc_id      = aws_vpc.main.id

  # HTTP público — Moodle precisa ser acessível pela Internet
  ingress {
    description = "HTTP público para o Moodle"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH restrito ao CIDR informado em var.ssh_allowed_cidr
  # AVISO: o valor padrão é 0.0.0.0/0; restrinja ao seu IP em produção
  ingress {
    description = "SSH restrito ao CIDR configurado (least privilege)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Egresso irrestrito: necessário para instalar pacotes e conectar ao RDS
  egress {
    description = "Egresso irrestrito"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# -----------------------------------------------------------------------------
# Security Group do RDS
# Ingresso: TCP 5432 apenas a partir do Security Group da EC2 (least privilege)
# O RDS nunca deve ser acessível diretamente pela Internet.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Permite PostgreSQL (5432) apenas a partir do SG da EC2."
  vpc_id      = aws_vpc.main.id

  # PostgreSQL — origem restrita ao SG da EC2 (não 0.0.0.0/0)
  ingress {
    description     = "PostgreSQL a partir do SG da EC2 (least privilege)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Egresso irrestrito"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# -----------------------------------------------------------------------------
# Data source: lê a região atual configurada no provider
# Usado para construir nomes de AZ dinamicamente (ex: us-east-1a, us-east-1b)
# -----------------------------------------------------------------------------
data "aws_region" "current" {}
