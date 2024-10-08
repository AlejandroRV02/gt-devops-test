resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }
}

resource "aws_security_group" "mongodb_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
}

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
      owner_uid = 1001
      owner_gid = 1001
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

resource "aws_alb" "frontend_alb" {
  name            = "${var.app_name}-alb"
  internal        = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.frontend_sg.id]
  subnets         = [aws_subnet.public.id]
}

resource "aws_route53_zone" "main" {
  name = var.zone_name
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.zone_name  # Aquí utilizas la variable para el dominio
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.zone_name}"]

  tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
  count = length(aws_acm_certificate.cert.domain_validation_options)

  zone_id = aws_route53_zone.main.zone_id
  name    = aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_type
  ttl     = 60
  records = [aws_acm_certificate.cert.domain_validation_options[count.index].resource_record_value]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn          = aws_acm_certificate.cert.arn
  validation_record_fqdns  = aws_route53_record.cert_validation[*].fqdn
}


resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.frontend_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.frontend_target_group.arn
  }
}


resource "aws_alb_target_group" "frontend_target_group" {
  name     = "${var.app_name}-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_alb_target_group_attachment" "frontend_attachment" {
  target_group_arn = aws_alb_target_group.frontend_target_group.arn
  target_id        = aws_ecs_service.frontend_service.id
  port             = 80
}
