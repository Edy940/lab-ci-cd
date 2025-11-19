data "aws_lb_target_group" "this" {
  name = "app-prod-tg"
}

data "aws_security_groups" "this" {
  filter {
    name   = "tag:Name"
    values = ["app-prod-sg"]
  }
}

data "aws_lb" "this" {
  name = var.lb_name
}

resource "aws_ecs_service" "this" {
  name                          = "app-service"
  task_definition               = "ci-cd-app"
  cluster                       = var.cluster_name
  desired_count                 = var.desired_count
  launch_type                   = "FARGATE"
  availability_zone_rebalancing = "ENABLED"
  network_configuration {
    subnets          = var.subnets_id
    security_groups  = data.aws_security_groups.this.ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.this.arn
    container_name   = "ci-cd-app"
    container_port   = 8000
  }

}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/ci-cd-app"
  retention_in_days = 7
}