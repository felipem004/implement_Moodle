# Requirements — Moodle Docker AWS Challenge

## Introdução

Este documento descreve os requisitos do desafio DevOps da Disciplina de ADS da UniFAAT. O projeto combina containerização com Docker, infraestrutura como código com Terraform e deploy na AWS via Learn Lab. O template entrega o ambiente Docker local funcional, workflows de CI/CD, testes automatizados e documentação de apoio. Os módulos Terraform, o `user_data.sh`, o documento de arquitetura e o workflow `terraform-plan.yml` são as entregas do aluno.

---

## Requirements

### 1. Ambiente Docker Local

#### 1.1
O comando `docker compose up -d` executado dentro de `docker/` deve subir todos os contêineres sem erros e sem configuração manual adicional.

#### 1.2
A URL `http://localhost:8080` deve retornar HTTP 200 com a interface do Moodle após os contêineres subirem.

#### 1.3
O serviço `moodle` deve depender do serviço `db` com `condition: service_healthy`, garantindo que o Moodle só inicia após o PostgreSQL estar pronto.

#### 1.4
Os dados devem persistir em volumes Docker nomeados (`db_data`, `moodle_data`, `moodle_www`) após reinício dos contêineres.

#### 1.5
O Dockerfile deve usar `php:8.1-apache` como imagem base e entregar o Moodle 4.1.

#### 1.6
O serviço `db` deve usar a imagem `postgres:15` com healthcheck via `pg_isready`.

#### 1.7
O `docker-compose.yml` deve mapear a porta `8080` do host para a porta `80` do contêiner Moodle.

#### 1.8
O arquivo `docker/.env.example` deve documentar todas as variáveis necessárias com valores de exemplo e comentários `# TODO:`.

#### 1.9
O ambiente Docker deve usar três volumes nomeados declarados explicitamente na seção `volumes:` do `docker-compose.yml`.

#### 1.10
O serviço `db` deve ter `restart: unless-stopped` e o serviço `moodle` também.

#### 1.11
O Dockerfile deve instalar explicitamente as nove extensões PHP obrigatórias do Moodle 4.x: `mbstring`, `curl`, `zip`, `simplexml`, `intl`, `pdo_pgsql`, `gd`, `opcache`, `sodium`.

---

### 2. Repositório e Configuração

#### 2.1
O repositório deve conter um arquivo `.gitignore` na raiz cobrindo os padrões sensíveis obrigatórios: `*.tfvars`, `terraform.tfstate`, `terraform.tfstate.backup`, `.env`, `*.pem`, `*.key`, `id_rsa`.

#### 2.2
O arquivo `.gitignore` deve garantir que `git check-ignore` retorne exit 0 para qualquer arquivo com nome correspondente aos padrões `*.pem`, `*.key`, `id_rsa` e `terraform.tfstate`.

#### 2.3
O arquivo `pyproject.toml` deve definir as dependências de teste (`pytest>=7.0`, `hypothesis>=6.0`, `pyyaml>=6.0`) sob o extra `[test]` e configurar o `pytest` para buscar testes em `tests/`.

#### 2.4
Todo arquivo de configuração com extensão `.yml`, `.yaml`, `.tf`, `.sh` ou `.env.example` nos diretórios `docker/` e `terraform/` deve conter ao menos um comentário `# TODO:`, com exceção de `terraform/versions.tf`.

#### 2.5
O diretório `terraform/.terraform/` gerado pelo `terraform init` não deve ser versionado no Git.

#### 2.6
O arquivo `terraform/backend.tf` não deve ser versionado no Git (apenas `backend.tf.example` é versionado).

#### 2.7
O arquivo `.terraform.lock.hcl` não deve ser versionado no Git.

---

### 3. Infraestrutura Terraform — Estrutura

#### 3.1
O diretório `terraform/` deve conter os arquivos raiz: `versions.tf`, `main.tf`, `variables.tf` e `outputs.tf`.

#### 3.2
O arquivo `terraform/versions.tf` deve declarar `required_version = ">= 1.5"` e o provider `hashicorp/aws` com versão `~> 5.0`.

#### 3.3
O arquivo `terraform/terraform.tfvars.example` deve existir documentando todas as variáveis com comentários `# TODO:` e sem valores reais de credenciais.

#### 3.4
Cada módulo Terraform (`networking`, `compute`, `database`) deve conter os três arquivos obrigatórios: `main.tf`, `variables.tf` e `outputs.tf`.

#### 3.5
O comando `terraform validate` deve passar sem erros no diretório `terraform/`.

#### 3.6
O comando `terraform fmt -check -recursive` deve passar sem erros no diretório `terraform/`.

---

### 4. Infraestrutura Terraform — Módulo `networking`

#### 4.1
O módulo deve criar uma VPC com CIDR `10.0.0.0/16`, `enable_dns_support = true` e `enable_dns_hostnames = true`.

#### 4.2
O módulo deve criar uma subnet pública `10.0.1.0/24` em `us-east-1a` com `map_public_ip_on_launch = true`.

#### 4.3
O módulo deve criar duas subnets privadas: `10.0.2.0/24` em `us-east-1a` e `10.0.3.0/24` em `us-east-1b`.

#### 4.4
O módulo deve criar um Internet Gateway associado à VPC.

#### 4.5
O módulo deve criar uma Route Table pública com rota `0.0.0.0/0 → IGW` e associá-la à subnet pública.

#### 4.6
O módulo deve criar um Security Group da EC2 com ingresso TCP 80 de `0.0.0.0/0` e TCP 22 do CIDR configurável via variável `ssh_allowed_cidr`.

#### 4.7
O módulo deve criar um Security Group do RDS com ingresso TCP 5432 restrito ao Security Group da EC2 (origem `security_groups`, nunca `0.0.0.0/0`).

#### 4.8
Os outputs obrigatórios do módulo são: `vpc_id`, `public_subnet_id`, `private_subnet_ids`, `ec2_security_group_id`, `rds_security_group_id`.

---

### 5. Infraestrutura Terraform — Módulo `database`

#### 5.1
O módulo deve criar um `aws_db_subnet_group` cobrindo as duas subnets privadas (mínimo 2 AZs distintas).

#### 5.2
O módulo deve criar uma instância `aws_db_instance` com `engine = "postgres"`, `engine_version = "15"`, `instance_class = "db.t3.micro"` e `allocated_storage = 20`.

#### 5.3
A instância RDS deve ter `publicly_accessible = false`.

#### 5.4
A instância RDS deve ter `skip_final_snapshot = true` no ambiente educacional.

#### 5.5
Os outputs obrigatórios do módulo são: `rds_endpoint`, `rds_port`, `rds_address`.

---

### 6. Infraestrutura Terraform — Módulo `compute`

#### 6.1
O módulo deve criar um `aws_key_pair` usando a variável sensível `ec2_public_key`.

#### 6.2
O módulo deve buscar a AMI mais recente do Amazon Linux 2023 via `data "aws_ami"` com filtros `al2023-ami-*-x86_64` e `virtualization-type = hvm`.

#### 6.3
O módulo deve referenciar o `LabRole` via `data "aws_iam_instance_profile"` com `name = "LabRole"`. Nenhum bloco `resource "aws_iam_role"` ou `resource "aws_iam_instance_profile"` deve existir.

#### 6.4
A instância EC2 deve ser do tipo `t3.medium` com `iam_instance_profile = data.aws_iam_instance_profile.lab_role.name`.

#### 6.5
O `user_data` da EC2 deve ser gerado via `templatefile()` injetando as variáveis `db_host`, `db_port`, `db_name`, `db_username` e `db_password` no arquivo `user_data.sh`.

#### 6.6
Os outputs obrigatórios do módulo são: `ec2_public_dns`, `ec2_instance_id`, `ec2_public_ip`.

---

### 7. Script `user_data.sh`

#### 7.1
O script deve aceitar a URL do Moodle como argumento posicional `$1` com fallback `${1:-http://localhost:8080}` (aplicável ao `health-check.sh`; no `user_data.sh`, as variáveis são injetadas pelo `templatefile()`).

#### 7.2
O script `health-check.sh` deve usar `set -euo pipefail` como primeira instrução após o shebang.

#### 7.3
O `user_data.sh` deve instalar o Docker Engine via `dnf` e habilitar o serviço com `systemctl enable --now docker`.

#### 7.4
O `user_data.sh` deve instalar o Docker Compose v2 como plugin em `/usr/local/lib/docker/cli-plugins/docker-compose`.

#### 7.5
O `user_data.sh` deve criar o arquivo `/opt/moodle/.env` com as variáveis de conexão ao RDS e aplicar `chmod 600`.

#### 7.6
O `user_data.sh` deve executar `docker compose up -d` a partir de `/opt/moodle/` no boot da instância.

#### 7.7
O `user_data.sh` deve redirecionar toda a saída para `/var/log/user-data.log` para facilitar o diagnóstico.

#### 7.8
Variáveis bash no `user_data.sh` que não são do Terraform (ex: `COMPOSE_VERSION`) devem ser escapadas com `$${VAR}` para não serem interpretadas pelo `templatefile()`.

---

### 8. Segurança

#### 8.1
Nenhuma credencial (senha, token, chave de acesso) deve aparecer em texto literal em arquivos versionados no Git.

#### 8.2
A variável `ssh_allowed_cidr` deve ter `description` com aviso explícito de segurança recomendando restrição ao IP do usuário em produção.

#### 8.3
As variáveis `db_password`, `db_username` e `ec2_public_key` devem ser declaradas com `sensitive = true` e sem valor `default`.

#### 8.4
O `docker-compose.yml` não deve conter credenciais em texto literal. Variáveis com keywords `PASSWORD`, `SECRET`, `KEY`, `TOKEN` devem usar o formato `${VAR_NAME}`.

#### 8.5
Nenhum bloco `resource` dos tipos `aws_iam_role`, `aws_iam_role_policy`, `aws_iam_user`, `aws_route53_*`, `aws_acm_*` ou `aws_cloudfront_*` deve existir nos módulos Terraform.

---

### 9. Outputs Raiz

#### 9.1
O arquivo `terraform/outputs.tf` raiz deve exportar: `vpc_id`, `ec2_public_dns`, `ec2_instance_id`, `rds_endpoint`, `rds_port` e `moodle_url`.

---

### 10. CI/CD — Workflows

#### 10.1
O workflow `docker-lint.yml` deve executar `hadolint` no `docker/Dockerfile` e validar a sintaxe do `docker-compose.yml` via `docker compose config --quiet`.

#### 10.2
O workflow `terraform-validate.yml` deve executar `terraform fmt -check -recursive` e `terraform validate` em pushes e pull requests para `main` que modifiquem arquivos `terraform/**`, condicionado à existência de `terraform/versions.tf`.

#### 10.3
O workflow `health-check.yml` deve ser acionado via `workflow_dispatch` com input `moodle_url` e executar `scripts/health-check.sh` contra a URL informada.

#### 10.4
O workflow `terraform-plan.yml` deve ser implementado pelo aluno com `workflow_dispatch`, configurando credenciais AWS via secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`, e executando `terraform init` seguido de `terraform plan -out=tfplan`.

#### 10.5
Todo step com instrução `run:` em qualquer workflow deve ter o campo `name:` preenchido com valor não vazio.

---

### 11. Documentação

#### 11.1
O arquivo `docs/architecture-design-template.md` deve conter as sete seções obrigatórias: `## Visão Geral`, `## Diagrama de Arquitetura`, `## Decisões de Design`, `## Componentes`, `## Segurança`, `## Escalabilidade`, `## Custo Estimado`.

#### 11.2
O aluno deve entregar o arquivo `docs/architecture-design.md` gerado a partir do template, com todos os blocos `<!-- TODO: -->` substituídos por conteúdo real. A ausência deste arquivo é critério eliminatório.

#### 11.3
Os sete arquivos de documentação de apoio devem existir em `docs/`: `architecture-design-template.md`, `architecture.md`, `aws-learn-lab-setup.md`, `terraform-guide.md`, `troubleshooting.md`, `evaluation-rubric.md`, `security-practices.md`.

#### 11.4
O diagrama em `docs/architecture-design.md` deve cobrir obrigatoriamente: VPC, subnets públicas e privadas, EC2, RDS, Security Groups e o fluxo Internet → IGW → EC2 → RDS.

#### 11.5
A seção "Custo Estimado" deve conter valores obtidos da AWS Pricing Calculator com link para a estimativa gerada.
