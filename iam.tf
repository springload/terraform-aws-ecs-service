data "aws_iam_policy_document" "ecs-assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task-role-alb" {
  count = local.balanced ? 1 : 0

  name = "${var.cluster_name}-${var.service_name}-alb"

  assume_role_policy = data.aws_iam_policy_document.ecs-assume.json
}


data "aws_iam_policy_document" "service_policy_alb" {
  count = local.balanced ? 1 : 0

  statement {
    actions = [
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
    ]

    resources = [
      data.aws_lb_target_group.TG[0].arn,
    ]
  }

  statement {
    actions = [
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "elasticloadbalancing:Describe*",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "service_policy_alb" {
  count = local.balanced ? 1 : 0

  name   = "${var.cluster_name}-${var.service_name}-alb"
  role   = aws_iam_role.task-role-alb[0].name
  policy = data.aws_iam_policy_document.service_policy_alb[0].json
}

