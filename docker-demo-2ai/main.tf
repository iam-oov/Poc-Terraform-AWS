locals {
  vpc_name = var.project_name
  azs      = slice(data.aws_availability_zones.available.names, 0, 2) # Usar las primeras 2 AZs

}

# --- Obtener Zonas de Disponibilidad ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Obtener Región Actual ---
data "aws_region" "current" {}

##################################################
## VPC y Redes
##################################################

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-vpc"
    }
  )
}

# --- Subredes Públicas ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true # Importante para subredes públicas

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-subnet-public${count.index + 1}-${local.azs[count.index]}"
      Tier = "Public"
    }
  )
}

# --- Subredes Privadas ---
# Estas subredes NO tendrán acceso a Internet directo.
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 3) # 10.0.3.0/24, 10.0.4.0/24
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-subnet-private${count.index + 1}-${local.azs[count.index]}"
      Tier = "Private"
    }
  )
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-igw"
    }
  )
}

# --- Tabla de Rutas Pública ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-rtb-public"
    }
  )
}

# --- Asociaciones de Ruta Pública ---
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Tablas de Rutas Privadas (Sin Salida a Internet) ---
# Necesarias para asociar el VPC Endpoint de S3
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  # No hay ruta 0.0.0.0/0 aquí, porque no hay NAT Gateway

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-rtb-private-${local.azs[count.index]}"
    }
  )
}

# --- Asociaciones de Ruta Privada ---
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

##################################################
## VPC Endpoints
##################################################

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  # Asocia el endpoint con las tablas de rutas de las subredes privadas.
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-vpce-s3"
    }
  )
}

##################################################
## Security Groups
##################################################

# --- Security Group para el ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "${local.vpc_name}-alb-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = aws_vpc.main.id

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

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-alb-sg"
    }
  )
}

# --- Security Group para las Tareas ECS/Contenedores ---
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${local.vpc_name}-ecs-tasks-sg"
  description = "Allow traffic from ALB on app port"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Permite tráfico SOLO desde el ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Permite salida (principalmente para VPC Endpoints)
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-ecs-tasks-sg"
    }
  )
}

##################################################
## Security Group para VPC Endpoints de Interfaz
##################################################

resource "aws_security_group" "vpce_sg" {
  name        = "${local.vpc_name}-vpce-sg"
  description = "Allow HTTPS traffic to Interface Endpoints from within VPC"
  vpc_id      = aws_vpc.main.id

  # Regla de Entrada: Permite HTTPS (443) desde el SG de las tareas ECS
  # Esto permite que tus contenedores se comuniquen con los endpoints.
  ingress {
    description = "HTTPS from ECS Tasks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # ¡IMPORTANTE! Referencia el SG de las tareas ECS.
    # Necesitarás tener 'aws_security_group.ecs_tasks_sg.id' disponible.
    # Si 'ecs_tasks_sg' está en main.tf, esto funciona. Si lo moviste, ajusta.
    # Basado en nuestra conversación, está en main.tf.
    security_groups = [aws_security_group.ecs_tasks_sg.id]
  }

  # Regla de Salida: Permite todo el tráfico saliente (dentro de la VPC).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-vpce-sg"
    }
  )
}


##################################################
## VPC Endpoints (Interfaz para ECR y Logs)
##################################################

locals {
  # Lista de servicios para los que crearemos Endpoints de Interfaz
  interface_endpoint_services = {
    ecr_api = "ecr.api"
    ecr_dkr = "ecr.dkr"
    logs    = "logs"
  }
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  # Usamos for_each para crear los 3 endpoints de forma eficiente
  for_each = local.interface_endpoint_services

  vpc_id = aws_vpc.main.id
  # Construye el nombre completo del servicio (ej: com.amazonaws.us-east-1.ecr.api)
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type = "Interface"

  # Asigna los endpoints a las subredes PRIVADAS
  subnet_ids = aws_subnet.private[*].id

  # Asigna el Security Group que creamos para los endpoints
  security_group_ids = [aws_security_group.vpce_sg.id]

  # Habilita DNS privado para que las llamadas a los servicios
  # (ej: ecr.us-east-1.amazonaws.com) se resuelvan al endpoint dentro de la VPC.
  private_dns_enabled = true

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-vpce-${replace(each.value, ".", "-")}" # ej: poc-node-hw-vpce-ecr-api
    }
  )
}

##################################################
## Application Load Balancer (ALB) y Target Group
##################################################

# --- Target Group (Tipo IP) ---
resource "aws_lb_target_group" "app_tg" {
  name        = "${local.vpc_name}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/" # Ajusta esto a tu endpoint de health check
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
      Name = "${local.vpc_name}-app-tg"
    }
  )
}

# --- Application Load Balancer ---
resource "aws_lb" "app_alb" {
  name               = "${local.vpc_name}-alb"
  internal           = false # Público
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  # El ALB se despliega en las subredes públicas para ser accesible
  subnets = aws_subnet.public[*].id

  enable_deletion_protection = false # Cambia a 'true' en producción

  tags = merge(
    var.common_tags,
    {
      Name = "${local.vpc_name}-alb"
    }
  )
}

# --- Listener del ALB (HTTP:80) ---
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
