# 1. The ECS Cluster (The "Management Plane")
resource "aws_ecs_cluster" "main" {
  name = "ai-saas-cluster"
}

# 2. IAM Role (Security: Allows Fargate to pull images & write logs)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 3. CloudWatch Log Group (Observability)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/ai-saas-backend"
  retention_in_days = 7
}

# 4. The Task Definition (The "Blueprint" for the container)
resource "aws_ecs_task_definition" "backend_task" {
  family                   = "ai-saas-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  # ✅ THIS WAS MISSING. It gives your Python code the S3/SQS permissions.
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  
  # This lets Fargate start the container (keep it)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "ai-saas-backend-container"
    image = "${aws_ecr_repository.backend_repo.repository_url}:latest"
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 5. The ECS Service (Run and maintain the container)
resource "aws_ecs_service" "backend_service" {
  name            = "ai-saas-backend-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets # Using public for now to test easily
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}

# 6. Security Group (Firewall)
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-backend-sg"
  description = "Allow port 8000"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to world for testing (We will lock this down later with ALB)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}