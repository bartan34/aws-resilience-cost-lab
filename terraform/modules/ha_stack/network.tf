module "network" {
  source = "../network"

  name   = var.name
  az_ids = var.az_ids
}

resource "aws_security_group" "alb" {
  name   = "${var.name}-alb"
  vpc_id = module.network.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-alb" }
}

resource "aws_security_group" "app" {
  name   = "${var.name}-app"
  vpc_id = module.network.vpc_id

  ingress {
    description     = "App port from the load balancer only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app" }
}

resource "aws_security_group" "db" {
  name   = "${var.name}-db"
  vpc_id = module.network.vpc_id

  ingress {
    description     = "MySQL from the app instances only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = { Name = "${var.name}-db" }
}