locals {
  task_family    = "${var.project_name}-fargate-awsvpc"
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
      Name = "${var.project_name}-log-group"
    }
  )
}

##################################################
## IAM Roles & Policies
##################################################

# --- Política de Confianza (Assume Role Policy) para Tareas ECS ---
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Rol de Tarea (Task Role) ---
# Este rol es para tu APLICACIÓN. Añade políticas aquí si tu app necesita llamar a AWS.
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-task-role"
    }
  )
}

# --- Rol de Ejecución (Execution Role) ---
# Este rol es para que ECS/FARGATE gestionen la tarea (logs, ECR).
resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.project_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-execution-role"
    }
  )
}

# --- Política para el Rol de Ejecución (Mínimos Permisos) ---
data "aws_iam_policy_document" "ecs_execution_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"] # ECR requiere '*' para estas acciones
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
  name        = "${var.project_name}-ecs-execution-policy"
  description = "Minimal permissions for ECS Fargate Task Execution"
  policy      = data.aws_iam_policy_document.ecs_execution_policy_doc.json
}

# --- Adjuntar Política al Rol de Ejecución ---
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

  # Define la estructura del contenedor usando jsonencode
  container_definitions = jsonencode([
    {
      name      = "node-hw"
      image     = var.app_image_uri
      essential = true
      portMappings = [
        {
          name          = "app-node-hw"
          containerPort = var.app_port
          hostPort      = var.app_port # En awsvpc/Fargate, hostPort y containerPort suelen ser iguales
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs" # Prefijo para los streams de logs
        }
      }
      # Puedes añadir variables de entorno aquí si es necesario
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
