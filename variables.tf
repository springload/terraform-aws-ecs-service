variable "cluster_name" {
  description = "Name of the ECS cluster"
}

variable "service_name" {
  description = "Name of the ECS service"
}

variable "target_group_name" {
  description = "Name of the ALB target group. Defaults to the `cluster_name` if not set"
  default     = ""
}

variable "target_group_names" {
  description = "Names of the ALB target groups. Defaults to the `[cluster_name]` if not set"
  default     = []
}


variable "environment" {
  description = "Enviropnment vars to pass to the container. Note: they will be visible in the task definition, so please don't pass any secrets here."
  type        = map
  default     = {}

}

variable "image" {
  description = "The image to use"
}

variable "cpu" {
  description = "Amount of CPU to use"
  default     = 0
}

variable "essential" {
  description = "Exit the task if contaner exits"
  default     = true
}

variable "memory" {
  description = "Amount of maximum memory the container can use"
  default     = 512
}

variable "memory_reservation" {
  description = "Amount of reserved memory for the container"
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
  type    = list
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
  type        = bool
  description = "Use embdedded to Docker tini init process that correctly reaps zombie processes"
  default     = true
}

variable "user" {
  type        = string
  description = "Run container as the specified user. Formats are: user, user:group, uid, uid:gid, user:gid, uid:group"
  default     = ""
}


locals {
  balanced                     = var.container_port > 0
  load_balancer_container_name = coalesce(var.load_balancer_container_name, var.service_name)

  target_group_names = coalescelist(distinct(compact(concat(var.target_group_names, list(var.target_group_name)))), list(var.cluster_name))

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

  defaultPortMappings = [
    {
      containerPort = var.container_port
    }
  ]
}

