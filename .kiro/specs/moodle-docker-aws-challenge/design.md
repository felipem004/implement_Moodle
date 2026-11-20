# Design — Moodle Docker AWS Challenge

## Visão Geral

O projeto é estruturado em quatro camadas independentes que se integram progressivamente: ambiente Docker local, infraestrutura Terraform na AWS, CI/CD via GitHub Actions e documentação técnica. O template entrega as camadas Docker e CI/CD funcionais; o aluno implementa Terraform e documentação.

```
implement_Moodle/
├── docker/              ← Ambiente local (entregue pelo template)
├── terraform/           ← Infraestrutura AWS (entregue pelo aluno)
├── .github/workflows/   ← CI/CD (3 prontos + 1 stub para o aluno)
├── scripts/             ← health-check.sh
├── tests/               ← Testes de propriedade (pytest + Hypothesis)
└── docs/                ← Documentação de apoio + template de arquitetura
```

---

## 1. Ambiente Docker Local

### 1.1 Stack de serviços

Dois serviços orquestrados pelo `docker-compose.yml`:

| Serviço | Imagem | Porta | Papel |
|---|---|---|---|
| `db` | `postgres:15` | — | Banco de dados PostgreSQL |
| `moodle` | build local (`php:8.1-apache`) | `8080:80` | Aplicação Moodle 4.1 |

A dependência entre serviços usa `condition: service_healthy` — o Moodle só inicia após o healthcheck do PostgreSQL (`pg_isready`) retornar sucesso.

### 1.2 Build da imagem Moodle

O Dockerfile segue esta sequência:

1. Base `php:8.1-apache`
2. Instala dependências de sistema via `apt-get` (libs para extensões PHP)
3. Configura `gd` com suporte JPEG (`docker-php-ext-configure gd --with-jpeg`)
4. Instala as 9 extensões obrigatórias via `docker-php-ext-install`
5. Configura OPcache e parâmetros PHP (`max_input_vars`, `upload_max_filesize`, etc.)
6. Baixa e extrai o Moodle 4.1 do repositório oficial para `/var/www/html`
7. Cria `/var/moodledata` com permissões para `www-data`
8. Habilita `mod_rewrite` no Apache

### 1.3 Variáveis de ambiente

Gerenciadas via `docker/.env` (copiado de `.env.example`, não versionado). O `docker-compose.yml` carrega via `env_file` e injeta via `environment` usando interpolação `${VAR}` — nunca valores literais.

### 1.4 Volumes

Três volumes nomeados garantem persistência independente do ciclo de vida dos contêineres:

| Volume | Montado em | Conteúdo |
|---|---|---|
| `db_data` | `/var/lib/postgresql/data` | Dados do PostgreSQL |
| `moodle_data` | `/var/www/html` | Código e arquivos do Moodle |
| `moodle_www` | `/var/moodledata` | Upload de usuários e cache |

---

## 2. Infraestrutura Terraform

### 2.1 Arquitetura AWS

```
Internet
    │ HTTP :80
    ▼
Internet Gateway
    │
Route Table Pública
    │
Subnet Pública 10.0.1.0/24 (us-east-1a)
    │
EC2 t3.medium (Amazon Linux 2023)
SG EC2: TCP 80 (0.0.0.0/0), TCP 22 (ssh_allowed_cidr)
    │ PostgreSQL :5432
    ▼
Subnet Privada 10.0.2.0/24 (us-east-1a)
RDS PostgreSQL 15 db.t3.micro
SG RDS: TCP 5432 ← origem: SG EC2 apenas

Subnet Privada 10.0.3.0/24 (us-east-1b)  ← exigida pelo aws_db_subnet_group
```

### 2.2 Organização dos módulos

A raiz `terraform/` instancia três módulos na seguinte ordem de dependência:

```
networking → database → compute
```

**`networking`** não tem dependências externas. Cria toda a camada de rede e exporta IDs de subnets e security groups.

**`database`** consome `private_subnet_ids` e `rds_security_group_id` do networking. Cria o subnet group e a instância RDS.

**`compute`** consome outputs de networking (`public_subnet_id`, `ec2_security_group_id`) e de database (`rds_endpoint`, `rds_port`). Cria o key pair, busca a AMI e provisiona a EC2.

### 2.3 Variáveis sensíveis

As variáveis `db_password`, `db_username` e `ec2_public_key` são declaradas com `sensitive = true` e sem `default`. Seus valores são fornecidos exclusivamente via `terraform.tfvars` (ignorado pelo Git).

### 2.4 Data sources

Dois data sources são usados para evitar hardcode e respeitar as restrições do Learn Lab:

| Data source | Propósito |
|---|---|
| `data "aws_iam_instance_profile" "lab_role"` | Referencia o `LabRole` pré-existente sem criar recursos IAM |
| `data "aws_ami" "amazon_linux_2023"` | Busca dinamicamente a AMI mais recente do Amazon Linux 2023 |
| `data "aws_region" "current"` | Lê a região configurada no provider para construir nomes de AZ |

### 2.5 user_data.sh e templatefile()

O `user_data.sh` é renderizado pelo `templatefile()` do Terraform antes de ser enviado à EC2. Cinco variáveis são injetadas: `db_host`, `db_port`, `db_name`, `db_username`, `db_password`. Variáveis bash que não são do Terraform (ex: `COMPOSE_VERSION`) devem ser escritas como `$${VAR}` para não serem interpretadas pelo Terraform como variáveis do template.

Sequência de execução no boot da EC2:
1. Atualiza pacotes (`dnf update -y`)
2. Instala Docker Engine (`dnf install -y docker`)
3. Habilita o serviço Docker (`systemctl enable --now docker`)
4. Baixa o Docker Compose v2 como plugin
5. Cria `/opt/moodle/docker-compose.yml` com a imagem Bitnami Moodle 4.1
6. Cria `/opt/moodle/.env` com `chmod 600` injetando as credenciais do RDS
7. Executa `docker compose up -d`

### 2.6 Restrições do AWS Learn Lab

O provider AWS no Learn Lab opera com o papel `LabRole` (STS temporário). Os seguintes tipos de recurso causam `AccessDenied` e **não devem ser usados**:

- `aws_iam_role`, `aws_iam_role_policy`, `aws_iam_instance_profile`, `aws_iam_user`
- `aws_route53_*`, `aws_acm_*`, `aws_cloudfront_*`

Alternativas: `LabRole` via data source; DNS público automático da EC2; HTTP porta 80 sem TLS.

---

## 3. Testes Automatizados

### 3.1 Estratégia

Os testes usam pytest + Hypothesis (property-based testing). Cada teste valida uma propriedade estrutural do repositório inspecionando o sistema de arquivos — sem requerer infraestrutura AWS ou contêineres em execução.

### 3.2 Mapeamento propriedade → arquivo de teste

| Propriedade | Arquivo | Requisitos validados |
|---|---|---|
| P1: Extensões PHP no Dockerfile | `test_dockerfile_extensions.py` | 1.5, 1.11 |
| P2: `# TODO:` em arquivos de configuração | `test_todo_comments.py` | 2.4 |
| P3: Padrões sensíveis no `.gitignore` | `test_gitignore_patterns.py` | 2.1 |
| P4: `git check-ignore` para arquivos sensíveis | `test_gitignore_patterns.py` | 2.2 |
| P5: Estrutura dos módulos Terraform | `test_terraform_module_structure.py` | 3.4 |
| P6: Steps com `name:` nos workflows | `test_workflow_step_comments.py` | 10.5 |
| P7: Arquivos de documentação obrigatórios | `test_docs_exist.py` | 11.3 |
| P8: Ausência de credenciais no compose | `test_compose_no_hardcoded_creds.py` | 8.4 |
| P9: `health-check.sh` aceita URL via `$1` | `test_health_check.py` | 7.1, 7.2 |
| P10: `set -euo pipefail` no health check | `test_health_check.py` | 7.2 |
| P11: Seções no template de arquitetura | `test_architecture_template_sections.py` | 11.1 |

### 3.3 Exceções deliberadas

O arquivo `terraform/versions.tf` está na lista `_EXCLUDED_FILES` do `test_todo_comments.py` — é o único `.tf` que não recebe `# TODO:` por design, pois é pré-preenchido e funcional como está.

---

## 4. CI/CD

### 4.1 Workflows entregues pelo template

| Workflow | Trigger | Jobs |
|---|---|---|
| `docker-lint.yml` | push/PR em `docker/**` | `hadolint` + `docker compose config` |
| `terraform-validate.yml` | push/PR em `terraform/**` (se `versions.tf` existir) | `fmt -check` + `validate` |
| `health-check.yml` | `workflow_dispatch` (input: `moodle_url`) | Executa `health-check.sh` |

### 4.2 Workflow entregue pelo aluno

`terraform-plan.yml` — stub com `on: {}` e `if: false`. O aluno deve:
1. Configurar o trigger (`workflow_dispatch`)
2. Implementar 5 steps: checkout → credenciais AWS → setup Terraform → `terraform init` → `terraform plan -out=tfplan`
3. Configurar os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` no repositório

---

## 5. Documentação de Arquitetura

O aluno copia `docs/architecture-design-template.md` para `docs/architecture-design.md` e preenche os blocos `<!-- TODO: -->`. O arquivo entregue deve cobrir as sete seções e o diagrama deve representar os componentes reais provisionados.

A ausência de `docs/architecture-design.md` no repositório entregue resulta em **desclassificação automática**, independentemente da pontuação nas demais categorias.

---

## 6. Fluxo de Trabalho Recomendado

```
Passo 1: Validar ambiente local
  └─ docker compose up -d
  └─ ./scripts/health-check.sh http://localhost:8080
  └─ pytest tests/ -v

Passo 2: Criar módulos Terraform
  ├─ terraform/versions.tf + main.tf + variables.tf + outputs.tf
  ├─ modules/networking/ (VPC, subnets, IGW, SGs)
  ├─ modules/database/  (RDS + subnet group)
  └─ modules/compute/   (EC2 + key pair + user_data.sh)
  └─ terraform init && terraform fmt && terraform validate

Passo 3: Preencher docs/architecture-design.md
  └─ cp docs/architecture-design-template.md docs/architecture-design.md
  └─ Substituir todos os <!-- TODO: --> por conteúdo real

Passo 4: Implementar terraform-plan.yml
  └─ Configurar secrets no GitHub
  └─ Implementar os 5 steps do stub

Passo 5: Deploy e validação
  └─ cp terraform.tfvars.example terraform.tfvars (preencher valores reais)
  └─ terraform apply
  └─ ./scripts/health-check.sh http://<EC2_DNS>
  └─ terraform destroy (ao final da sessão do Learn Lab)
```
