resource "aws_lb" "app" {
  name               = var.name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.network.subnet_ids
}

resource "aws_lb_target_group" "app" {
  name                 = var.name
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = module.network.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}