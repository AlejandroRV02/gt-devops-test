resource "aws_alb" "frontend_alb" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_sg.id]
  subnets            = [aws_subnet.public.id]
}

resource "aws_alb_target_group" "frontend_target_group" {
  name     = "${var.app_name}-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
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

resource "aws_alb_target_group_attachment" "frontend_attachment" {
  target_group_arn = aws_alb_target_group.frontend_target_group.arn
  target_id        = aws_ecs_service.frontend_service.id
  port             = 80
}
