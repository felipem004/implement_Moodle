# =============================================================================
# modules/compute/main.tf
# Cria o key pair, busca a AMI mais recente do Amazon Linux 2023,
# referencia o LabRole via data source e provisiona a instância EC2.
#
# Restrições do AWS Learn Lab aplicadas:
#   - IAM via data source (data "aws_iam_instance_profile") — NÃO cria aws_iam_role
#   - AMI Amazon Linux 2023 buscada dinamicamente via data source
# =============================================================================

# -----------------------------------------------------------------------------
# Key Pair — usa a chave pública fornecida via variável sensível
# -----------------------------------------------------------------------------
resource "aws_key_pair" "moodle" {
  key_name   = "${var.project_name}-key"
  public_key = var.ec2_public_key

  tags = {
    Name = "${var.project_name}-key"
  }
}

# -----------------------------------------------------------------------------
# Data source: busca o LabRole existente no AWS Learn Lab
# NÃO cria aws_iam_role — o Learn Lab bloqueia a criação de roles IAM.
# O LabRole é pré-existente na conta Academy e deve ser referenciado assim.
# -----------------------------------------------------------------------------
data "aws_iam_instance_profile" "lab_role" {
  name = "LabRole"
}

# -----------------------------------------------------------------------------
# Data source: AMI mais recente do Amazon Linux 2023 (x86_64)
# Usar data source garante que sempre buscamos a versão mais atual,
# sem hardcodar o AMI ID (que varia por região e muda com atualizações).
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------------------------------------------------------------
# Instância EC2
# O user_data.sh é renderizado via templatefile() com as variáveis do RDS,
# garantindo que o Moodle seja configurado automaticamente no primeiro boot.
# -----------------------------------------------------------------------------
resource "aws_instance" "moodle" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [var.ec2_security_group_id]
  key_name               = aws_key_pair.moodle.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.lab_role.name

  # Renderiza o user_data.sh injetando as variáveis de conexão ao RDS
  user_data = templatefile("${path.module}/user_data.sh", {
    db_host     = var.rds_endpoint
    db_port     = var.rds_port
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
  })

  # Garante que a instância seja recriada se o user_data mudar
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
