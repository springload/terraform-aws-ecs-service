resource "aws_ecs_task_definition" "task" {
  family = "${var.cluster_name}-${var.service_name}"

  cpu                = local.use_fargate ? var.cpu : null
  memory             = local.use_fargate ? var.memory : null
  execution_role_arn = local.use_fargate ? aws_iam_role.task-execution-role.arn : null
  network_mode       = local.use_fargate ? "awsvpc" : "bridge"

  container_definitions = jsonencode([for s in concat([
    {
      name              = var.service_name
      image             = var.image
      cpu               = var.cpu
      essential         = var.essential
      links             = var.links
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
    portMappings = local.balanced && local.load_balancer_container_name == s.name ? local.port_mappings : []
  })])

  requires_compatibilities = [local.use_fargate ? "FARGATE" : "EC2"]

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


  // can't use this for Fargate
  dynamic "ordered_placement_strategy" {
    for_each = !local.use_fargate ? [
      { type = "spread", field = "attribute:ecs.availability-zone" },
      { type = "spread", field = "instanceId" },
    ] : []
    iterator = each

    content {
      type  = each.value.type
      field = each.value.field
    }
  }

  dynamic "load_balancer" {
    for_each = local.balanced ? zipmap(data.aws_lb_target_group.TG[*].arn, var.port_mappings) : {}

    content {
      target_group_arn = load_balancer.key
      container_name   = local.load_balancer_container_name
      container_port   = load_balancer.value.containerPort
    }
  }

  // Fargate-specifics
  // For launch_type we use capacity providers in case of Fargate
  // to utilise Fargate_spot if we need to
  launch_type = local.use_fargate ? null : "EC2"

  dynamic "capacity_provider_strategy" {
    for_each = local.use_fargate ? [{}] : []

    content {
      capacity_provider = var.fargate_spot ? "FARGATE_SPOT" : "FARGATE"
      weight            = 100
    }
  }

  dynamic "network_configuration" {
    for_each = local.use_fargate ? [{}] : []

    content {
      subnets         = var.subnet_ids
      security_groups = var.security_groups
      // hardcode it for now
      // otherwise it requires private links everywhere of NAT
      assign_public_ip = true
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
    sourceVolume  = "${var.cluster_name}-${efs_vol.efs_id}"
    containerPath = lookup(efs_vol, "container_path", "/private_storage")
  }]

  task_def_all_mount_points = concat(local.task_def_ro_mount_points, local.task_def_efs_mount_points)
}
