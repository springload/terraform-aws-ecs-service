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
  description = "Enviropnment vars to pass to the container. Note: they will be visible in the task definition, so please don't pass any secrets here."
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
  description = "Exit the task if contaner exits"
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
  description = "Minimum number of healty contianers during deployments"
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum number of healty contianers during deployments"
  default     = 200
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "init_process_enabled" {
  description = "Use embdedded to Docker tini init process that correctly reaps zombie processes"
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

