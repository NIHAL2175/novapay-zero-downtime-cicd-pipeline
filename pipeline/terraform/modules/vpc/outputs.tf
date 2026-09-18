output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.novapay.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (EKS worker nodes)"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of database subnets (RDS)"
  value       = aws_subnet.database[*].id
}

output "nat_gateway_ips" {
  description = "Public IPs of NAT gateways"
  value       = aws_eip.nat[*].public_ip
}
