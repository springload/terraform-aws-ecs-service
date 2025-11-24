output "task-definition-arn" {
  description = "Arn of the task definition"
  value       = aws_ecs_task_definition.task.arn
}
output "task-definition-family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.task.family
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role used by the ECS service"
  value       = aws_iam_role.task-execution-role.arn
}

output "fargate_spot" {
  description = "Whether Fargate Spot launch type is enabled"
  value       = var.fargate_spot
}

output "fargate" {
  description = "Whether Fargate launch type is enabled"
  value       = var.fargate
}
