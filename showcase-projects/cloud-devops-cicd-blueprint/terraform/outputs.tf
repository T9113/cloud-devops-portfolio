output "vpc_id" {
  description = "ID of the created AWS VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app_sg.id
}
