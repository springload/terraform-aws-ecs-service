resource "aws_appautoscaling_target" "ecs_service" {
  count              = var.use_fargate_scaling ? 1 : 0
  max_capacity       = var.fargate_max_capacity
  min_capacity       = var.fargate_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_ecs_service.service]

  lifecycle {
    precondition {
      condition     = var.fargate_max_capacity >= var.fargate_min_capacity
      error_message = "Maximum capacity must be greater than or equal to minimum capacity."
    }
  }
}

resource "aws_appautoscaling_policy" "cpu_utilization" {
  count              = var.use_fargate_scaling && var.fargate_scale_by_cpu ? 1 : 0
  name               = "${aws_ecs_service.service.name}-cpu-utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.fargate_cpu_target_value
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }

  depends_on = [aws_appautoscaling_target.ecs_service]
}

resource "aws_appautoscaling_policy" "memory_utilization" {
  count              = var.use_fargate_scaling && var.fargate_scale_by_memory ? 1 : 0
  name               = "${aws_ecs_service.service.name}-memory-utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.fargate_memory_target_value
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }

  depends_on = [aws_appautoscaling_target.ecs_service]
}
