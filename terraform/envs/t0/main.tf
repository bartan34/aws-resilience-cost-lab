module "network" {
  source = "../../modules/network"

  name   = "ca2-t0"
  az_ids = ["euw1-az1"]
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

locals {
  ecr_registry = "742752463962.dkr.ecr.eu-west-1.amazonaws.com"
  image        = "${local.ecr_registry}/ca2-app:323a9e2"
}

module "instance_role" {
  source = "../../modules/instance_role"

  name = "ca2-t0-instance"
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_security_group" "app" {
  name   = "ca2-t0-app"
  vpc_id = module.network.vpc_id

  ingress {
    description = "App HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ca2-t0-app" }
}

resource "aws_instance" "app" {
  ami                    = "ami-01feb2929337f1f0f"
  instance_type          = "t4g.medium"
  subnet_id              = module.network.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = module.instance_role.instance_profile_name

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region       = "eu-west-1"
    ecr_registry = local.ecr_registry
    image        = local.image
    db_password  = random_password.db.result
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
    tags        = { Project = "CA2", Tier = "T0" }
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "ca2-t0-app" }
}

resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = { Name = "ca2-t0" }
}

output "app_url" {
  value = "http://${aws_eip.app.public_ip}:8080"
}

output "instance_id" {
  value = aws_instance.app.id
}

output "ami_id" {
  value = aws_instance.app.ami
}