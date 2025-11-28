resource "aws_cloudwatch_log_group" "main" {
  count = local.log_awslogs ? 1 : 0

  name              = "awslogs-${var.cluster_name}-${var.service_name}"
  retention_in_days = var.log_retention_days
}

