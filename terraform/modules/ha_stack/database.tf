data "aws_availability_zone" "primary" {
  zone_id = var.az_ids[0]
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/ca2/${lower(var.tier)}/db_password"
  type  = "SecureString"
  value = random_password.db.result
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = module.network.subnet_ids
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "mysql"
  engine_version = "8.4"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "ca2"
  username = "ca2"
  password = random_password.db.result

  multi_az               = var.multi_az
  availability_zone      = var.multi_az ? null : data.aws_availability_zone.primary.name
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period    = 0
  auto_minor_version_upgrade = false
  skip_final_snapshot        = true
  apply_immediately          = true
}