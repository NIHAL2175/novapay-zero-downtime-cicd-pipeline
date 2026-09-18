output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.novapay.endpoint
}

output "db_instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.novapay.identifier
}

output "db_security_group_id" {
  description = "Security group ID of the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.novapay.name
}
