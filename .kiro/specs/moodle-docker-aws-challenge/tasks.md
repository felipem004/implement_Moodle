# Tasks — Moodle Docker AWS Challenge

## Fase 1 — Ambiente Docker Local

- [x] 1.1 Copiar `docker/.env.example` para `docker/.env` e substituir as senhas pelos valores reais
- [x] 1.2 Executar `docker compose up -d` a partir de `docker/` e confirmar que todos os contêineres atingem o estado `running`
- [x] 1.3 Validar o acesso ao Moodle em `http://localhost:8080` (HTTP 200 com interface Moodle)
- [x] 1.4 Executar `./scripts/health-check.sh http://localhost:8080` e confirmar `exit 0`
- [x] 1.5 Instalar dependências de teste: `pip install pytest hypothesis pyyaml`
- [x] 1.6 Executar `pytest tests/ -v` e confirmar que todos os testes do template passam (os de módulo Terraform ficam como `SKIPPED` até a Fase 2)

## Fase 2 — Infraestrutura Terraform

### 2.1 Configurar credenciais AWS

- [x] 2.1.1 Acessar o portal AWS Academy → Learner Lab → Start Lab
- [x] 2.1.2 Copiar as credenciais temporárias (AWS Details → AWS CLI) para `~/.aws/credentials`
- [x] 2.1.3 Criar `~/.aws/config` com `region = us-east-1` e `output = json`
- [x] 2.1.4 Validar com `aws sts get-caller-identity` (saída deve conter `UserId`, `Account`, `Arn`)

### 2.2 Criar módulos Terraform

- [x] 2.2.1 Criar `terraform/versions.tf` com provider AWS `~> 5.0` e `required_version >= 1.5`
- [x] 2.2.2 Criar `terraform/variables.tf` com todas as variáveis raiz (região, projeto, CIDRs, EC2, DB)
- [x] 2.2.3 Criar `terraform/main.tf` instanciando os três módulos na ordem: networking → database → compute
- [x] 2.2.4 Criar `terraform/outputs.tf` exportando `vpc_id`, `ec2_public_dns`, `ec2_instance_id`, `rds_endpoint`, `rds_port`, `moodle_url`
- [x] 2.2.5 Criar `terraform/terraform.tfvars.example` documentando todas as variáveis com comentários `# TODO:`
- [x] 2.2.6 Criar `terraform/modules/networking/variables.tf`, `main.tf`, `outputs.tf`
- [x] 2.2.7 Criar `terraform/modules/database/variables.tf`, `main.tf`, `outputs.tf`
- [x] 2.2.8 Criar `terraform/modules/compute/variables.tf`, `main.tf`, `outputs.tf`
- [x] 2.2.9 Criar `terraform/modules/compute/user_data.sh` com instalação do Docker, Docker Compose v2 e `docker compose up -d`
- [x] 2.2.10 Executar `terraform init` no diretório `terraform/`
- [x] 2.2.11 Executar `terraform fmt -check -recursive` e corrigir eventuais problemas de formatação
- [x] 2.2.12 Executar `terraform validate` e confirmar `Success! The configuration is valid.`
- [x] 2.2.13 Executar `pytest tests/ -v` e confirmar **64/64 testes passando**

### 2.3 Configurar variáveis e planejar

- [ ] 2.3.1 Copiar `terraform.tfvars.example` para `terraform.tfvars`
- [ ] 2.3.2 Gerar chave SSH: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/moodle_key`
- [ ] 2.3.3 Preencher `terraform.tfvars` com valores reais (chave pública, credenciais do banco, IP para SSH)
- [ ] 2.3.4 Executar `terraform plan` e revisar o plano (12 recursos esperados)

### 2.4 Aplicar e validar na AWS

- [ ] 2.4.1 Executar `terraform apply` e aguardar conclusão (anote o `ec2_public_dns` do output)
- [ ] 2.4.2 Aguardar 3-5 minutos para o `user_data.sh` concluir o boot da EC2
- [ ] 2.4.3 Executar `./scripts/health-check.sh http://<EC2_DNS>` e confirmar `exit 0`
- [ ] 2.4.4 Verificar no console AWS que todos os recursos foram criados (EC2, RDS, VPC, SGs)
- [ ] 2.4.5 Ao final da sessão, executar `terraform destroy` para liberar o crédito do Learn Lab

## Fase 3 — Documento de Arquitetura

- [ ] 3.1 Copiar o template: `cp docs/architecture-design-template.md docs/architecture-design.md`
- [ ] 3.2 Preencher a seção "Visão Geral" (2-4 parágrafos sobre a solução implementada)
- [ ] 3.3 Criar o diagrama de arquitetura cobrindo VPC, subnets, EC2, RDS, SGs e fluxo Internet → IGW → EC2 → RDS
- [ ] 3.4 Preencher a tabela "Decisões de Design" com justificativas técnicas reais
- [ ] 3.5 Preencher a seção "Componentes" descrevendo cada recurso AWS provisionado
- [ ] 3.6 Preencher a seção "Segurança" cobrindo isolamento de rede, SGs, credenciais e IAM
- [ ] 3.7 Preencher a seção "Escalabilidade" com limitações atuais e caminhos para produção
- [ ] 3.8 Preencher a seção "Custo Estimado" usando a AWS Pricing Calculator e adicionar o link gerado
- [ ] 3.9 Confirmar que nenhum `<!-- TODO: -->` permanece no arquivo entregue

## Fase 4 — Workflow terraform-plan.yml

- [ ] 4.1 Implementar o trigger `workflow_dispatch` no `.github/workflows/terraform-plan.yml`
- [ ] 4.2 Implementar o Step 1: checkout do repositório (`actions/checkout@v4`)
- [ ] 4.3 Implementar o Step 2: configurar credenciais AWS (`aws-actions/configure-aws-credentials@v4`) com os três secrets
- [ ] 4.4 Implementar o Step 3: instalar Terraform (`hashicorp/setup-terraform@v3`)
- [ ] 4.5 Implementar o Step 4: `terraform init`
- [ ] 4.6 Implementar o Step 5: `terraform plan -out=tfplan`
- [ ] 4.7 Configurar os secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN` em Settings → Secrets → Actions do repositório no GitHub
- [ ] 4.8 Disparar o workflow via `workflow_dispatch` e confirmar execução com sucesso

## Fase 5 — Validação Final

- [ ] 5.1 Executar `pytest tests/ -v` e confirmar todos os testes passando
- [ ] 5.2 Confirmar que `docs/architecture-design.md` existe e está sem `<!-- TODO: -->`
- [ ] 5.3 Confirmar que `git ls-files` não retorna nenhum `.pem`, `.key`, `.env` real, `tfstate` ou `terraform.tfvars`
- [ ] 5.4 Confirmar que todos os workflows do GitHub Actions têm histórico de execuções bem-sucedidas na aba Actions
- [ ] 5.5 Executar `./scripts/health-check.sh http://<EC2_DNS>` e confirmar `exit 0`
- [ ] 5.6 Revisar o checklist de segurança em `docs/security-practices.md` (seção 9)
