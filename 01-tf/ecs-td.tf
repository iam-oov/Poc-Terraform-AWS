locals {
  task_family    = "${var.project_name_prefix}-fargate-awsvpc"
  log_group_name = "/ecs/${local.task_family}"
}

##################################################
## Logging
##################################################

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-log-group"
    }
  )
}

##################################################
## IAM Roles & Policies
##################################################

# --- Policy to allow ECS tasks to assume roles ---
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Task Role ---
# This role is for your APPLICATION. Add policies here if your app needs to call AWS.
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-ecs-task-role"
    }
  )
}

# --- Execution Role ---
# This role is for ECS/FARGATE to manage the task (logs, ECR).
resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.project_name_prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-ecs-execution-role"
    }
  )
}

# --- Execution Policy ---
data "aws_iam_policy_document" "ecs_execution_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"] # ECR requires '*' for these actions
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.ecs_log_group.arn}:*"]
  }
}

resource "aws_iam_policy" "ecs_execution_policy" {
  name        = "${var.project_name_prefix}-ecs-execution-policy"
  description = "Minimal permissions for ECS Fargate Task Execution"
  policy      = data.aws_iam_policy_document.ecs_execution_policy_doc.json
}

# --- Attach Policy to Execution Role ---
resource "aws_iam_role_policy_attachment" "ecs_execution_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_policy.arn
}

##################################################
## ECS Task Definition
##################################################

resource "aws_ecs_task_definition" "app_task" {
  family                   = local.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  # Define the container structure using jsonencode
  container_definitions = jsonencode([
    {
      name      = "node-hw"
      image     = var.app_image_uri
      essential = true
      portMappings = [
        {
          name          = "app-node-hw"
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # environment = [
      #   { name = "VAR_NAME", value = "VAR_VALUE" }
      # ]
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = merge(
    var.common_tags,
    {
      Name = local.task_family
    }
  )
}
