# -----------------------------------------------------------------------------
# variables.tf - Definiciones de Variables para el Proyecto POC Node.js en ECS
# -----------------------------------------------------------------------------

# --- Variables Generales del Proyecto y AWS ---

variable "project_name" {
  description = "Nombre base para los recursos (VPC, ALB, ECS, etc.)"
  type        = string
  default     = "poc-terraform-node-hw"
}

variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "log_retention_days" {
  description = "Días de retención para los logs en CloudWatch"
  type        = number
  default     = 3
}

# --- Variables de Red (VPC) ---

variable "vpc_cidr" {
  description = "Bloque CIDR para la VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

# --- Variables de la Aplicación y Contenedor ---

variable "app_port" {
  description = "Puerto en el que escucha la aplicación dentro del contenedor"
  type        = number
  default     = 3011
}

variable "app_image_uri" {
  description = "URI completa de la imagen Docker en ECR para la aplicación"
  type        = string
  # IMPORTANTE: Asegúrate de que este sea el URI correcto de tu imagen
  default = "058264118467.dkr.ecr.us-east-1.amazonaws.com/myapp"
}

# --- Variables de ECS Fargate ---

variable "fargate_cpu" {
  description = "Unidades de CPU para la tarea Fargate (ej: 256, 512, 1024)"
  type        = string
  default     = "1024" # 1 vCPU
}

variable "fargate_memory" {
  description = "Memoria en MiB para la tarea Fargate (ej: 512, 1024, 2048)"
  type        = string
  default     = "2048" # 2 GB
}

variable "common_tags" {
  description = "Tags a aplicar a todos los recursos"
  type        = map(string)
  default = {
    Project     = "poc-terraform-node-hw"
    Terraform   = "true"
    Environment = "poc"
  }
}
