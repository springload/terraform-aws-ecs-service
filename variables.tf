variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "target_group_name" {
  description = "Name of the ALB target group. Defaults to the `cluster_name` if not set"
  type        = string
  default     = ""
}

variable "target_group_names" {
  description = "Names of the ALB target groups. Defaults to the `[cluster_name]` if not set"
  type        = list(string)
  default     = []
}
variable "target_group_arns" {
  description = "ARNs of the ALB target groups. Overrides target_group_names."
  type        = list(string)
  default     = []
}
variable "fargate" {
  type        = bool
  default     = false
  description = "Indicates it's going to be a Fargate service. Requires FARGATE capability of the cluster"
}

variable "fargate_spot" {
  type        = bool
  default     = false
  description = "Indicates it's going to be a Fargate spot service. Requires FARGATE_SPOT capability of the cluster"
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "List of subnet ids. Required for Fargate tasks as they have to use awsvpc networking"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "List of security group ids. Required for Fargate tasks as they have to use awsvpc networking"
}

variable "environment" {
  description = "Environment vars to pass to the container. Note: they will be visible in the task definition, so please don't pass any secrets here."
  type        = map(any)
  default     = {}

}

variable "links" {
  description = "Links the main container to specified ones"
  type        = list(string)
  default     = []
}

variable "image" {
  description = "The Docker image to use"
  type        = string
}

variable "cpu" {
  description = "Amount of CPU to use"
  type        = number
  default     = 0
}

variable "essential" {
  description = "Exit the task if container exits"
  type        = bool
  default     = true
}

variable "memory" {
  description = "Amount of maximum memory the container can use"
  type        = number
  default     = 512
}

variable "memory_reservation" {
  description = "Amount of reserved memory for the container"
  type        = number
  default     = 256
}

variable "container_port" {
  type    = number
  default = 0
}

variable "load_balancer_container_name" {
  description = "Name of the container that will used by the load balancer. Can be used to put nginx proxy in front of the app. Defaults to the service name"
  type        = string
  default     = ""
}

variable "additional_container_definitions" {
  type    = list(any)
  default = []
}

variable "task_role_arn" {
  type    = string
  default = ""
}

variable "port_mappings" {
  type    = list(any)
  default = []
}

variable "log_configuration" {
  type = object({
    logDriver = string
    options   = map(any)
  })
  default = { logDriver = "", options = {} }
}

variable "readonlyRootFilesystem" {
  type        = bool
  description = "Enforce read-only access to the file system inside of the Docker container"
  default     = false
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum number of healthy containers during deployments"
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum number of healthy containers during deployments"
  default     = 200
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "init_process_enabled" {
  description = "Use embedded Docker tini init process that correctly reaps zombie processes"
  type        = bool
  default     = true
}

variable "user" {
  description = "Run container as the specified user. Formats are: user, user:group, uid, uid:gid, user:gid, uid:group"
  type        = string
  default     = ""
}

variable "use_default_capacity_provider" {
  description = "Use the cluster default capacity provider"
  type        = bool
  default     = false
}

variable "efs_volumes" {
  description = "Optional list of efs volumes, which are a map with {efs_id:, root_dir:}"
  type        = list(map(string))
  default     = []
}

variable "enable_execute_command" {
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service."
  type        = bool
  default     = true
}

variable "use_fargate_scaling" {
  description = "Whether to use ECS service auto-scaling policies. Tested with Fargate; should work with EC2 but not verified."
  type        = bool
  default     = false
}

variable "fargate_max_capacity" {
  description = "The maximum number of tasks for ECS service auto-scaling. AWS requires this to be at least 1. To scale to 0, set min_capacity to 0 and disable autoscaling, or set desired_count to 0 directly."
  type        = number
  default     = 10

  validation {
    condition     = var.fargate_max_capacity > 0
    error_message = "Maximum capacity must be greater than 0 (AWS Application Auto Scaling requirement). To scale to 0, set min_capacity to 0 and disable autoscaling, or set desired_count to 0."
  }
}

variable "fargate_min_capacity" {
  description = "The minimum number of tasks for ECS service auto-scaling. Set to 0 to allow scaling down to zero tasks."
  type        = number
  default     = 1

  validation {
    condition     = var.fargate_min_capacity >= 0
    error_message = "Minimum capacity must be greater than or equal to 0."
  }
}

variable "fargate_cpu_target_value" {
  description = "The target value for CPU utilization in ECS service auto-scaling"
  type        = number
  default     = 70
}

variable "fargate_memory_target_value" {
  description = "The target value for memory utilization in ECS service auto-scaling"
  type        = number
  default     = 85
}

variable "fargate_scale_by_memory" {
  description = "Whether to enable memory-based scaling for ECS service"
  type        = bool
  default     = true
}

variable "fargate_scale_by_cpu" {
  description = "Whether to enable CPU-based scaling for ECS service"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "The number of days to retain log events. Set to 0 for never expire."
  type        = number
  default     = 0
}

locals {
  balanced                     = var.container_port > 0 || length(var.port_mappings) > 0
  load_balancer_container_name = coalesce(var.load_balancer_container_name, var.service_name)

  target_group_names = coalescelist(distinct(compact(concat(var.target_group_names, [var.target_group_name]))), [var.cluster_name])

  default_log_configuration = {
    "logDriver" = "awslogs"
    "options" = {
      "awslogs-group"         = aws_cloudwatch_log_group.main[0].name
      "awslogs-region"        = data.aws_region.current.name
      "awslogs-stream-prefix" = var.service_name
    }
  }
  log_awslogs       = var.log_configuration["logDriver"] == ""
  log_configuration = local.log_awslogs ? local.default_log_configuration : var.log_configuration

  port_mappings = coalescelist(var.port_mappings, [
    {
      containerPort = var.container_port
    }
  ])
  use_fargate = var.fargate || var.fargate_spot

  target_group_arns = local.balanced ? (length(var.target_group_arns) > 0 ? var.target_group_arns : data.aws_lb_target_group.TG[*].arn) : []
}
