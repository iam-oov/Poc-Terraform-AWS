##################################################
## Application Load Balancer (ALB) & Target Group
##################################################

# --- Target Group (type ip) ---
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name_prefix}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-app-tg"
    }
  )
}

# --- Application Load Balancer ---
resource "aws_lb" "app_alb" {
  name               = "${var.project_name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  # The ALB is deployed in public subnets to be accessible
  subnets = aws_subnet.public[*].id

  # ! Important
  # ! Change to 'true' in production
  enable_deletion_protection = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-alb"
    }
  )
}

# --- Listener of the ALB (HTTP:80) ---
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
