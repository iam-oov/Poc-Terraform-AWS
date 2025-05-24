##################################################
## ECS Cluster Fargate
##################################################

resource "aws_ecs_cluster" "main_cluster" {
  name = "${var.project_name_prefix}-cluster-fargate"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-cluster-fargate"
    }
  )
}

##################################################
## ECS Service
##################################################

resource "aws_ecs_service" "main_service" {
  name             = "${var.project_name_prefix}-service"
  cluster          = aws_ecs_cluster.main_cluster.id
  task_definition  = aws_ecs_task_definition.app_task.arn
  desired_count    = var.task_desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  health_check_grace_period_seconds = 60

  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"

  deployment_controller {
    type = "ECS"
  }
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets = [
      aws_subnet.private[0].id,
      aws_subnet.private[1].id
    ]
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "node-hw"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.http_listener]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-service"
    }
  )
}
