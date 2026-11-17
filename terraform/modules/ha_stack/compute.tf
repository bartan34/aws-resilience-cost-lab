module "instance_role" {
  source = "../instance_role"

  name = "${var.name}-instance"
}

resource "aws_iam_role_policy" "db_password" {
  name = "read-db-password"
  role = module.instance_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = aws_ssm_parameter.db_password.arn
    }]
  })
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = module.instance_role.instance_profile_name
  }

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 16
      volume_type = "gp3"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    region            = var.region
    ecr_registry      = var.ecr_registry
    image             = var.image
    db_host           = aws_db_instance.this.address
    db_password_param = aws_ssm_parameter.db_password.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app", Project = "CA2", Tier = var.tier }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-app", Project = "CA2", Tier = var.tier }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-app"
  min_size            = 2
  max_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = module.network.subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 180

  wait_for_elb_capacity     = 2
  wait_for_capacity_timeout = "15m"

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  depends_on = [aws_iam_role_policy.db_password]
}