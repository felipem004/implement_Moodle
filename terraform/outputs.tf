# =============================================================================
# outputs.tf — Outputs raiz expostos após o terraform apply
# =============================================================================

# TODO: Adicione outputs extras conforme necessário (ex: ec2_public_ip, rds_address).

output "vpc_id" {
  description = "ID da VPC criada pelo módulo networking."
  value       = module.networking.vpc_id
}

output "ec2_public_dns" {
  description = "DNS público da EC2. Use para acessar o Moodle: http://<ec2_public_dns>"
  value       = module.compute.ec2_public_dns
}

output "ec2_instance_id" {
  description = "ID da instância EC2 (útil para verificação no console AWS e SSH)."
  value       = module.compute.ec2_instance_id
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL (host:porta). Usado internamente pelo Moodle via VPC."
  value       = module.database.rds_endpoint
}

output "rds_port" {
  description = "Porta do RDS PostgreSQL."
  value       = module.database.rds_port
}

output "moodle_url" {
  description = "URL completa para acessar o Moodle na EC2."
  value       = "http://${module.compute.ec2_public_dns}"
}
