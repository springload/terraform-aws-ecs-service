output "task-definition-arn" {
  description = "Arn of the task definition"
  value       = aws_ecs_task_definition.task.arn
}
output "task-definition-family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.task.family
}

output "task_execution_role_arn" {
  value = aws_iam_role.task-execution-role.arn
}