# =============================================================================
# modules/compute/outputs.tf
# =============================================================================

# TODO: Adicione o output ec2_private_ip se precisar referenciar o IP privado em outros recursos.

output "ec2_public_dns" {
  description = "DNS público da EC2. Use para acessar o Moodle: http://<ec2_public_dns>"
  value       = aws_instance.moodle.public_dns
}

output "ec2_instance_id" {
  description = "ID da instância EC2 (útil para verificação no console AWS)."
  value       = aws_instance.moodle.id
}

output "ec2_public_ip" {
  description = "IP público da EC2."
  value       = aws_instance.moodle.public_ip
}
