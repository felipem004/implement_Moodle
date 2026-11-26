#!/bin/bash
# =============================================================================
# user_data.sh — Script de inicialização da EC2 (Amazon Linux 2023)
#
# Executado automaticamente no primeiro boot da instância pelo cloud-init.
# Instala o Docker, faz o build da imagem Moodle e sobe os contêineres.
#
# Variáveis injetadas pelo templatefile() do Terraform:
#   ${db_host}     — hostname do RDS PostgreSQL (sem porta)
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
# 2. Instalar o Docker Engine
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instalando Docker..."
dnf install -y docker

systemctl enable --now docker
usermod -aG docker ec2-user

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker instalado: $(docker --version)"

# =============================================================================
# 3. Instalar o Docker Compose v2 como plugin
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instalando Docker Compose v2..."

COMPOSE_VERSION="v2.27.1"
mkdir -p /usr/local/lib/docker/cli-plugins

curl -fsSL \
  "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker Compose instalado: $(docker compose version)"

# =============================================================================
# 4. Preparar o diretório da aplicação
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Preparando diretório da aplicação..."

APP_DIR="/opt/moodle"
mkdir -p "$APP_DIR"

# =============================================================================
# 5. Criar o Dockerfile (mesmo usado no ambiente local do projeto)
# =============================================================================
cat > "$APP_DIR/Dockerfile" << 'DOCKERFILE_EOF'
FROM php:8.1-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libonig-dev libzip-dev libicu-dev libpq-dev \
    libpng-dev libjpeg-dev libsodium-dev libxml2-dev \
    libcurl4-openssl-dev curl unzip git \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-jpeg

RUN docker-php-ext-install \
    mbstring curl zip simplexml intl pdo_pgsql gd opcache sodium

RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.max_accelerated_files=10000'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { \
    echo 'max_input_vars=5000'; \
    echo 'post_max_size=128M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'memory_limit=256M'; \
    echo 'max_execution_time=300'; \
} > /usr/local/etc/php/conf.d/moodle-recommended.ini

RUN curl -fsSL \
    "https://download.moodle.org/download.php/direct/stable401/moodle-latest-401.tgz" \
    -o /tmp/moodle.tgz \
    && tar -xzf /tmp/moodle.tgz -C /tmp \
    && cp -r /tmp/moodle/. /var/www/html/ \
    && rm -rf /tmp/moodle.tgz /tmp/moodle \
    && chown -R www-data:www-data /var/www/html

RUN mkdir -p /var/moodledata \
    && chown -R www-data:www-data /var/moodledata \
    && chmod 0770 /var/moodledata \
    && ln -s /var/moodledata /var/www/moodledata

RUN a2enmod rewrite
EXPOSE 80
DOCKERFILE_EOF

# =============================================================================
# 6. Criar o docker-compose.yml usando build local
# =============================================================================
cat > "$APP_DIR/docker-compose.yml" << 'COMPOSE_EOF'
services:
  moodle:
    build:
      context: /opt/moodle
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "80:80"
    env_file:
      - /opt/moodle/.env
    volumes:
      - moodle_www:/var/www/html
      - moodle_data:/var/moodledata

volumes:
  moodle_www:
  moodle_data:
COMPOSE_EOF

# =============================================================================
# 7. Criar o .env com as credenciais do RDS
# db_host já vem sem porta (apenas o hostname)
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Criando arquivo .env..."

cat > "$APP_DIR/.env" << ENV_EOF
MOODLE_DATABASE_TYPE=pgsql
MOODLE_DATABASE_HOST=${db_host}
MOODLE_DATABASE_PORT_NUMBER=${db_port}
MOODLE_DATABASE_NAME=${db_name}
MOODLE_DATABASE_USER=${db_username}
MOODLE_DATABASE_PASSWORD=${db_password}
ENV_EOF

chmod 600 "$APP_DIR/.env"

# =============================================================================
# 8. Build e inicialização do Moodle
# O build leva ~5-10 minutos pois baixa o Moodle 4.1 (~60MB)
# =============================================================================
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fazendo build da imagem Moodle (aguarde ~10 min)..."
cd "$APP_DIR"
docker compose build

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Subindo o Moodle..."
docker compose up -d

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Moodle iniciado. Acesse: http://$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)"
# TODO: Adicione verificações extras de saúde após o docker compose up -d se necessário.
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuração concluída."
