##################################################
## VPC and Subnets
##################################################

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2) # Use the first 2 AZs
}

# --- Get available AZs ---
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Get current region ---
data "aws_region" "current" {}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-vpc"
    }
  )
}

# --- Public Subnets ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true # Important for public subnets

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-subnet-public${count.index + 1}-${local.azs[count.index]}"
      Tier = "Public"
    }
  )
}

# --- Private Subnets ---
# These subnets will not have direct access to the Internet.
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 3) # 10.0.3.0/24, 10.0.4.0/24
  availability_zone = local.azs[count.index]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-subnet-private${count.index + 1}-${local.azs[count.index]}"
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
      Name = "${var.project_name_prefix}-igw"
    }
  )
}

# --- Public Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-rtb-public"
    }
  )
}

# --- Public Route Table Association ---
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Route Table ---
# Required to associate the S3 VPC Endpoint
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-rtb-private-${local.azs[count.index]}"
    }
  )
}

# --- Private Route Table Association ---
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

  # Associate the endpoint with the private route tables
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-vpce-s3"
    }
  )
}

##################################################
## Security Groups
##################################################

# --- Security Group for the ALB ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name_prefix}-alb-sg"
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
      Name = "${var.project_name_prefix}-alb-sg"
    }
  )
}

# --- Security Group for ECS Tasks/Containers ---
resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${var.project_name_prefix}-ecs-tasks-sg"
  description = "Allow traffic from ALB on app port"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Allow traffic ONLY from the ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic (mainly for VPC Endpoints)
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-ecs-tasks-sg"
    }
  )
}

##################################################
## Security Group for VPC Endpoints of Interface
##################################################

resource "aws_security_group" "vpce_sg" {
  name        = "${var.project_name_prefix}-vpce-sg"
  description = "Allow HTTPS traffic to Interface Endpoints from within VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from ECS Tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id]
  }

  # Allow outbound traffic (mainly for VPC Endpoints)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-vpce-sg"
    }
  )
}


##################################################
## VPC Endpoints (Interface for ECR and Logs)
##################################################

locals {
  # List of services for which we will create Interface Endpoints
  interface_endpoint_services = {
    ecr_api = "ecr.api"
    ecr_dkr = "ecr.dkr"
    logs    = "logs"
  }
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  # Use for_each to create the 3 endpoints efficiently
  for_each = local.interface_endpoint_services

  vpc_id = aws_vpc.main.id
  # Build the full service name (e.g., com.amazonaws.us-east-1.ecr.api)
  service_name      = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type = "Interface"

  # Assign the endpoints to the PRIVATE subnets
  subnet_ids = aws_subnet.private[*].id

  # Assign the Security Group we created for the endpoints
  security_group_ids = [aws_security_group.vpce_sg.id]

  # Enable private DNS for the endpoints
  private_dns_enabled = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name_prefix}-vpce-${replace(each.value, ".", "-")}" # e.g: poc-node-hw-vpce-ecr-api
    }
  )
}
