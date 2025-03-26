############ ALB CONFIGURATION ###########
resource "aws_lb" "app_lb" {
  name               = "clinic-ms-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id] # Ajusta el Security Group
  subnets            = ["subnet-02b0cdcaa2b63c717", "subnet-0c2cba9a1b375e50b", "subnet-06299c7a0d12af21a"]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true
}

############ FRONTEND TARGET GROUP ###########
# Este grupo de destino es el que está asociado con CloudFront y servirá el contenido del frontend desde S3
resource "aws_lb_target_group" "frontend_target_group" {
  name        = "frontend-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta tu VPC

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

############ LISTENER CONFIGURATION ###########
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_target_group.arn # Redirige todo el tráfico a S3 (frontend)
  }
}

resource "aws_lb_listener" "httpalt_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.php-myadmin.arn # Redirige todo el tráfico a S3 (frontend)
  }
}

############ RULE FOR REDIRECTING TO BACKEND ###########
# CloudFront manejará el backend, no el ALB directamente
resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"] # Ruta para tráfico del backend, no es manejado directamente por el ALB
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_app_target_group.arn # Redirige a ECS para el backend
  }
}
resource "aws_lb_listener_rule" "frontend_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 20

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}


resource "aws_lb_listener_rule" "php-myadmin_rule" {
  listener_arn = aws_lb_listener.httpalt_listener.arn
  priority     = 30

  condition {
    path_pattern {
      values = ["/*"] # Ruta para tráfico del backend, no es manejado directamente por el ALB
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.php-myadmin.arn # Redirige a ECS para el backend
  }
}

############ PYTHON-APP TARGET GROUP ###########
# Grupo de destino que maneja el tráfico del backend, ya asociado al ECS
resource "aws_lb_target_group" "python_app_target_group" {
  name        = "python-app-tg"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta tu VPC

  health_check {
    path                = "/api/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    protocol            = "HTTP"
    matcher             = "200"
  }
}

############ php myadmin TARGET GROUP ###########
resource "aws_lb_target_group" "php-myadmin" {
  name        = "php-myadmin"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta tu VPC

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

############ FRONTEND TARGET GROUP ###########
resource "aws_lb_target_group" "frontend" {
  name        = "frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta tu VPC

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

/*resource "aws_lb" "app_lb" {
  name               = "clinic-ms-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id] # Ajusta el Security Group
  subnets            = ["subnet-02b0cdcaa2b63c717", "subnet-0c2cba9a1b375e50b", "subnet-06299c7a0d12af21a"]

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_target_group.arn
  }
}

# Regla para redirigir tráfico al backend
resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 10

  condition {
    path_pattern {
      values = ["/api/*"] # Ruta para tráfico del backend
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.python_app_target_group.arn
  }
}

############ FRONTEND TARGET GROUP ###########

resource "aws_lb_target_group" "frontend_target_group" {
  name        = "frontend-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta tu VPC

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

############ PYTHON-APP TARGET GROUP ###########

resource "aws_lb_target_group" "python_app_target_group" {
  name        = "python-app-tg"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta tu VPC

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    protocol            = "HTTP"
    matcher             = "200"
  }
}*/
