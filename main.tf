resource "aws_ecs_task_definition" "task" {
  family = "${var.cluster_name}-${var.service_name}"
  container_definitions = jsonencode([
    {
      name              = var.service_name
      image             = var.image
      cpu               = var.cpu
      essential         = var.essential
      memory            = var.memory
      memoryReservation = var.memory_reservation
      portMappings      = local.balanced ? coalescelist(var.port_mappings, local.defaultPortMappings) : []
      mountPoints       = []
      logConfiguration  = local.log_configuration
      environment       = [for k in sort(keys(var.environment)) : { "name" : k, "value" : var.environment[k] }]
      volumesFrom       = []
    }
  ])

  task_role_arn = var.task_role_arn

}


resource "aws_ecs_service" "service" {
  name                               = var.service_name
  cluster                            = data.aws_ecs_cluster.main.cluster_name
  task_definition                    = "${aws_ecs_task_definition.task.family}:${aws_ecs_task_definition.task.revision}"
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  dynamic "load_balancer" {
    for_each = local.balanced ? data.aws_lb_target_group.TG[*].arn : []

    content {
      target_group_arn = load_balancer.value
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }
}

