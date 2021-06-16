// creates task execution role for Fargate tasks
// as per https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
//

data "aws_iam_policy_document" "ecs-tasks-assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task-execution-role" {
  name = "${var.cluster_name}-${var.service_name}-execution"

  assume_role_policy = data.aws_iam_policy_document.ecs-tasks-assume.json
}


resource "aws_iam_role_policy_attachment" "task-execution-role-attach" {
  role = aws_iam_role.task-execution-role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
