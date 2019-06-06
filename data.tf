data "aws_ecs_cluster" "main" {
  cluster_name = var.cluster_name
}

data "aws_region" "current" {}


data "aws_lb_target_group" "TG" {
  count = local.balanced ? 1 : 0

  name = local.target_group_name
}
