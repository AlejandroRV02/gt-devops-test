resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.app_name}-cluster"
}

resource "aws_ecs_task_definition" "frontend" {
  family                = "${var.app_name}-frontend"
  network_mode         = "awsvpc"

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = var.frontend_image
    essential = true
    memory    = 512
    cpu       = 256
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

resource "aws_ecs_task_definition" "backend" {
  family                = "${var.app_name}-backend"
  network_mode         = "awsvpc"

  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image
    essential = true
    memory    = 512
    cpu       = 256
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
  }])
}

resource "aws_efs_file_system" "mongo_efs" {
  tags = var.tags
}

resource "aws_efs_access_point" "mongo_access_point" {
  file_system_id = aws_efs_file_system.mongo_efs.id

  posix_user {
    uid = 1001
    gid = 1001
  }

  root_directory {
    path = "/mongodb"
    creation_info {
      owner_uid  = 1001
      owner_gid  = 1001
      permissions = "750"
    }
  }
}

resource "aws_ecs_task_definition" "mongodb" {
  family                = "${var.app_name}-mongodb"
  network_mode         = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                   = "256"
  memory                = "512"

  container_definitions = jsonencode([{
    name      = "mongodb"
    image     = "mongo:latest"
    essential = true
    memory    = 512
    cpu       = 256
    portMappings = [{
      containerPort = 27017
      hostPort      = 27017
      protocol      = "tcp"
    }]
    mountPoints = [{
      source_volume  = "mongo-data"
      container_path = "/data/db"
    }]
  }])

  volume {
    name = "mongo-data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.mongo_efs.id
      root_directory = "/mongodb"
    }
  }
}

resource "aws_ecs_service" "frontend_service" {
  name            = "${var.app_name}-frontend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "backend_service" {
  name            = "${var.app_name}-backend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    assign_public_ip = false
  }
}

resource "aws_ecs_service" "mongodb_service" {
  name            = "${var.app_name}-mongodb-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.mongodb.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private.id]
    assign_public_ip = false
  }
}
