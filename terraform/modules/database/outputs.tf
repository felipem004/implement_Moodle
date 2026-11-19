# =============================================================================
# modules/database/outputs.tf
# =============================================================================

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL no formato host:porta. Usado pelo user_data.sh da EC2."
  value       = aws_db_instance.moodle.endpoint
}

output "rds_port" {
  description = "Porta do RDS PostgreSQL (5432)."
  value       = aws_db_instance.moodle.port
}

output "rds_address" {
  description = "Hostname do RDS sem a porta (útil para configurar MOODLE_DATABASE_HOST)."
  value       = aws_db_instance.moodle.address
}
