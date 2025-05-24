# ##################################################
# ## Outputs from ecs-cluster.tf
# ##################################################

# output "ecs_cluster_name" {
#   description = "The name of the created ECS Cluster"
#   value       = aws_ecs_cluster.main_cluster.name
# }

# output "ecs_cluster_arn" {
#   description = "The ARN of the created ECS Cluster"
#   value       = aws_ecs_cluster.main_cluster.arn
# }

# output "ecs_service_name" {
#   description = "The name of the created ECS Service"
#   value       = aws_ecs_service.main_service.name
# }

# ##################################################
# ## Outputs from ecs-td.tf
# ##################################################

# output "ecs_task_definition_arn" {
#   description = "The ARN of the created ECS Task Definition"
#   value       = aws_ecs_task_definition.app_task.arn
# }

# output "ecs_task_role_arn" {
#   description = "The ARN of the ECS Task Role"
#   value       = aws_iam_role.ecs_task_role.arn
# }

# output "ecs_execution_role_arn" {
#   description = "The ARN of the ECS Execution Role"
#   value       = aws_iam_role.ecs_execution_role.arn
# }

# output "cloudwatch_log_group_name" {
#   description = "The name of the CloudWatch Log Group"
#   value       = aws_cloudwatch_log_group.ecs_log_group.name
# }

# ##################################################
# ## Outputs from main.tf
# ##################################################

# output "vpc_id" {
#   description = "The ID of the created VPC"
#   value       = aws_vpc.main.id
# }

# output "public_subnet_ids" {
#   description = "List of Public Subnet IDs"
#   value       = aws_subnet.public[*].id
# }

# output "private_subnet_ids" {
#   description = "List of Private Subnet IDs (Now without Internet access, but with S3 access)"
#   value       = aws_subnet.private[*].id
# }



# output "alb_security_group_id" {
#   description = "The ID of the ALB Security Group"
#   value       = aws_security_group.alb_sg.id
# }

# output "ecs_tasks_security_group_id" {
#   description = "The ID of the ECS Tasks Security Group"
#   value       = aws_security_group.ecs_tasks_sg.id
# }

# output "target_group_arn" {
#   description = "The ARN of the Target Group"
#   value       = aws_lb_target_group.app_tg.arn
# }

# output "s3_vpc_endpoint_id" {
#   description = "The ID of the S3 Gateway VPC Endpoint"
#   value       = aws_vpc_endpoint.s3_gateway.id
# }
