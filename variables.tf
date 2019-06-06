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
  default = 0
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

variable "deployment_minimum_healthy_percent" {
  description = "Minimum number of healty contianers during deployments"
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Maximum number of healty contianers during deployments"
  default     = 200
}

variable "desired_count" {
  default = 1
}

locals {
  balanced          = var.container_port > 0
  target_group_name = coalesce(var.target_group_name, var.cluster_name)

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

