# =============================================================================
# modules/database/main.tf
# Cria o subnet group e a instância RDS PostgreSQL 15.
#
# Requisitos de segurança aplicados:
#   - publicly_accessible = false: o RDS não recebe IP público
#   - Subnets privadas: sem rota para o Internet Gateway
#   - Security Group restrito: 5432 apenas do SG da EC2
# =============================================================================

# TODO: Em produção, defina skip_final_snapshot = false e configure final_snapshot_identifier
# para garantir backup antes de destruir o banco.

# -----------------------------------------------------------------------------
# Subnet Group do RDS
# O aws_db_subnet_group exige ao menos 2 subnets em AZs distintas.
# Usamos as duas subnets privadas criadas pelo módulo networking.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "moodle" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group do RDS com subnets privadas em 2 AZs (us-east-1a e us-east-1b)."
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# Instância RDS PostgreSQL 15
#
# Configurações-chave:
#   - engine_version = "15": compatível com o ambiente Docker local (postgres:15)
#   - instance_class = "db.t3.micro": menor tipo disponível, minimiza custo no Lab
#   - publicly_accessible = false: banco isolado da Internet (least privilege)
#   - skip_final_snapshot = true: simplifica o destroy no ambiente educacional
# -----------------------------------------------------------------------------
resource "aws_db_instance" "moodle" {
  identifier        = "${var.project_name}-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.moodle.name
  vpc_security_group_ids = [var.rds_security_group_id]

  # Mantém o RDS privado — sem IP público, acessível apenas dentro da VPC
  publicly_accessible = false

  # skip_final_snapshot = true simplifica o terraform destroy no ambiente educacional.
  # Em produção, defina como false e configure final_snapshot_identifier.
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-db"
  }
}
