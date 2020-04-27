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
      mountPoints       = local.task_def_all_mount_points
      volumesFrom       = []
      linuxParameters = {
        initProcessEnabled = var.init_process_enabled
      }
      readonlyRootFilesystem = var.readonlyRootFilesystem
      user                   = var.user != "" ? var.user : null
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

  dynamic "volume" {
    for_each = local.task_def_efs_volumes

    content {
      name = volume.value.name
      efs_volume_configuration {
        file_system_id = volume.value.efs_id
        root_directory = volume.value.root_directory
      }
    }
  }

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

locals {
  task_def_ro_mount_points = var.readonlyRootFilesystem ? [{ sourceVolume = "tmp", containerPath = "/tmp" }] : []

  task_def_efs_volumes = [for efs_vol in var.efs_volumes : {
      name           = "${var.cluster_name}-${efs_vol.efs_id}"
      efs_id         = efs_vol.efs_id
      root_directory = lookup(efs_vol, "root_dir", "/mnt/efs")
    }]

  task_def_efs_mount_points = [for efs_vol in var.efs_volumes : {
      sourceVolume           = "${var.cluster_name}-${efs_vol.efs_id}"
      containerPath = lookup(efs_vol, "container_path", "/private_storage")
    }]

  task_def_all_mount_points = concat(local.task_def_ro_mount_points, local.task_def_efs_mount_points)
}