resource "aws_ecs_task_definition" "task" {
  family = "${var.cluster_name}-${var.service_name}"
  container_definitions = jsonencode([for s in concat([
    {
      name              = var.service_name
      image             = var.image
      cpu               = var.cpu
      essential         = var.essential
      memory            = var.memory
      memoryReservation = var.memory_reservation
      mountPoints       = var.readonlyRootFilesystem ? [{ sourceVolume = "tmp", containerPath = "/tmp" }] : []
      volumesFrom       = []
      linuxParameters = {
        initProcessEnabled = var.init_process_enabled
      }
      readonlyRootFilesystem = var.readonlyRootFilesystem
      user                   = var.user
    }
    ], var.additional_container_definitions) : merge(s, {
    environment = [for k in sort(keys(var.environment)) : { "name" : k, "value" : var.environment[k] }]
    # leverage the new terraform syntax and override the awslogs-stream-prefix
    logConfiguration = merge(local.log_configuration,
      local.log_configuration["logDriver"] == "awslogs" && local.log_configuration["options"] != null ? {
        options = merge(local.log_configuration["options"], { "awslogs-stream-prefix" = s.name })
      } : {}
    )
    # load balancer the local.load_balancer_container_name
    portMappings = local.balanced && local.load_balancer_container_name == s.name ? coalescelist(var.port_mappings, local.defaultPortMappings) : []
  })])

  task_role_arn = var.task_role_arn

  # the /tmp volume is needed if the root fs is readonly
  # tmpfs takes precious memory, so it's easier to create a volume
  dynamic "volume" {
    for_each = var.readonlyRootFilesystem ? [{}] : []
    content {
      name = "tmp"
      docker_volume_configuration {
        scope = "task"
      }
    }
  }
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
      container_name   = local.load_balancer_container_name
      container_port   = var.container_port
    }
  }
}

