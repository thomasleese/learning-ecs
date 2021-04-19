terraform {
  required_version = "0.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_ecr_repository" "main" {
  name = "learning-ecs"
}

resource "aws_ecs_cluster" "main" {
  name = "learning-ecs"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${aws_ecs_cluster.main.name}-task"
  container_definitions    = jsonencode([
    {
      name = "${aws_ecs_cluster.main.name}-task"
      image = aws_ecr_repository.main.repository_url
      cpu = 256
      memory = 512
      essential = true
      portMappings = [
        {
          containerPort = 4567
          hostPort = 4567
        }
      ]
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_default_vpc" "default" { }

resource "aws_default_subnet" "default_a" {
  availability_zone = "eu-west-2a"
}

resource "aws_default_subnet" "default_b" {
  availability_zone = "eu-west-2b"
}

resource "aws_default_subnet" "default_c" {
  availability_zone = "eu-west-2c"
}

resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "main" {
  name            = "${aws_ecs_cluster.main.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = [
      aws_default_subnet.default_a.id,
      aws_default_subnet.default_b.id,
      aws_default_subnet.default_c.id
    ]
    assign_public_ip = true
    security_groups  = [aws_security_group.service_security_group.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = aws_ecs_task_definition.main.family
    container_port   = 4567
  }
}

resource "aws_alb" "main" {
  name               = "${aws_ecs_cluster.main.name}-lb"
  load_balancer_type = "application"
  subnets            = [
    aws_default_subnet.default_a.id,
    aws_default_subnet.default_b.id,
    aws_default_subnet.default_c.id,
  ]
  security_groups    = [aws_security_group.load_balancer_security_group.id]
}

resource "aws_lb_target_group" "main" {
  name        = "${aws_ecs_cluster.main.name}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default.id

  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
