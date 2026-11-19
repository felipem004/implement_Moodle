#!/bin/bash
# =============================================================================
# user_data.sh — Script de inicialização da EC2 (Amazon Linux 2023)
#
# Executado automaticamente no primeiro boot da instância pelo cloud-init.
# Instala o Docker, configura o ambiente Moodle e sobe os contêineres.
#
# Variáveis injetadas pelo templatefile() do Terraform:
#   ${db_host}     — endpoint do RDS PostgreSQL (host:porta)
#   ${db_port}     — porta do RDS
#   ${db_name}     — nome do banco de dados
#   ${db_username} — usuário do banco
#   ${db_password} — senha do banco
#
# Log de execução: /var/log/user-data.log
# =============================================================================
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando configuração da instância EC2..."

# =============================================================================
# 1. Atualizar pacotes do sistema
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Atualizando pacotes do sistema..."
dnf update -y

# =============================================================================
# 2. Instalar o Docker Engine (via repositório oficial no Amazon Linux 2023)
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instalando Docker..."
dnf install -y docker

# Habilita e inicia o serviço Docker
systemctl enable --now docker

# Adiciona o usuário ec2-user ao grupo docker para operações sem sudo
usermod -aG docker ec2-user

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker instalado: $(docker --version)"

# =============================================================================
# 3. Instalar o Docker Compose v2 como plugin Docker
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instalando Docker Compose v2..."

# Cria o diretório de plugins do Docker para o usuário root e ec2-user
mkdir -p /usr/local/lib/docker/cli-plugins
mkdir -p /home/ec2-user/.docker/cli-plugins

# Baixa o binário do Docker Compose v2 (versão compatível com Amazon Linux 2023)
COMPOSE_VERSION="v2.27.1"
curl -fsSL \
  "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Cria symlink global para que 'docker compose' funcione para todos os usuários
ln -sf /usr/local/lib/docker/cli-plugins/docker-compose \
       /home/ec2-user/.docker/cli-plugins/docker-compose

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker Compose instalado: $(docker compose version)"

# =============================================================================
# 4. Preparar o diretório da aplicação Moodle
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configurando diretório da aplicação..."

APP_DIR="/opt/moodle"
mkdir -p "$APP_DIR"

# =============================================================================
# 5. Criar o docker-compose.yml para a EC2
# Usa a imagem Docker Hub do Bitnami Moodle (não requer build local na EC2)
# O RDS externo é referenciado via variáveis de ambiente.
# =============================================================================
cat > "$APP_DIR/docker-compose.yml" << 'COMPOSE_EOF'
# docker-compose.yml — Moodle na EC2 com RDS externo
# Gerado automaticamente pelo user_data.sh no boot da instância.

services:
  moodle:
    image: bitnami/moodle:4.1
    restart: unless-stopped
    ports:
      - "80:8080"
    env_file:
      - .env
    volumes:
      - moodle_data:/bitnami/moodle
      - moodle_sitedata:/bitnami/moodledata

volumes:
  moodle_data:
  moodle_sitedata:
COMPOSE_EOF

# =============================================================================
# 6. Criar o arquivo .env com as variáveis de conexão ao RDS
# As variáveis são injetadas pelo templatefile() do Terraform.
# O arquivo .env NÃO é versionado no Git (.gitignore).
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Criando arquivo .env com credenciais do RDS..."

cat > "$APP_DIR/.env" << ENV_EOF
# Conexão com o RDS PostgreSQL externo (gerado pelo user_data.sh)
MOODLE_DATABASE_TYPE=pgsql
MOODLE_DATABASE_HOST=${db_host}
MOODLE_DATABASE_PORT_NUMBER=${db_port}
MOODLE_DATABASE_NAME=${db_name}
MOODLE_DATABASE_USER=${db_username}
MOODLE_DATABASE_PASSWORD=${db_password}

# Usuário administrador inicial do Moodle
MOODLE_USERNAME=admin
MOODLE_PASSWORD=Admin@Moodle2024!
MOODLE_SITE_NAME=Moodle Challenge AWS

# Desabilita o banco local do Bitnami (usamos RDS externo)
MOODLE_SKIP_BOOTSTRAP=no
ENV_EOF

# Restringe permissões do .env — só root pode ler (contém senha do banco)
chmod 600 "$APP_DIR/.env"

# =============================================================================
# 7. Subir o Moodle com docker compose
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Subindo o Moodle com docker compose..."

cd "$APP_DIR"
docker compose up -d

echo "[$(date '+%Y-%m-%d %H:%M:%S')] docker compose up -d executado."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] O Moodle pode levar 3-5 minutos para concluir a instalação."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Acompanhe: docker compose logs -f moodle"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuração da instância EC2 concluída."
