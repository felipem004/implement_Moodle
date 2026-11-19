# =============================================================================
# modules/networking/outputs.tf
# =============================================================================

output "vpc_id" {
  description = "ID da VPC criada."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID da subnet pública onde a EC2 será alocada."
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Lista com os IDs das duas subnets privadas (AZ-A e AZ-B) para o subnet group do RDS."
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "ec2_security_group_id" {
  description = "ID do Security Group da EC2 (portas 80 e 22)."
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "ID do Security Group do RDS (porta 5432, origem: SG da EC2)."
  value       = aws_security_group.rds.id
}
