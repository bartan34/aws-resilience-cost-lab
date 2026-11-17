output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_az" {
  value = aws_db_instance.this.availability_zone
}

output "app_url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}