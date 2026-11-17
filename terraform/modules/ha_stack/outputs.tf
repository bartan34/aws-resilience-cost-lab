output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_az" {
  value = aws_db_instance.this.availability_zone
}