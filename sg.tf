############ SG APLICATION LOAD BALANCER ###########
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta con tu VPC

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permitir desde cualquier origen (ajusta según tus requisitos)
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB Security Group"
  }
}

############ SG ECS TASK ###########
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Security group for ECS tasks"

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Puede ajustarse a una red más restrictiva
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################### SG PHP-MY-ADMIN ######################
resource "aws_security_group_rule" "allow_http_phpmyadmin" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.ecs_sg.id
  cidr_blocks       = ["0.0.0.0/0"] # Sustituye "tu-ip/cidr" por tu IP o rango permitido
}

resource "aws_security_group_rule" "allow_phpmyadmin_to_rds" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.ecs_sg.id # Asegúrate de que ecs_sg esté declarado
}

#################### SG RDS ############################
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security Group for RDS instance"
  vpc_id      = "vpc-053917e74d7c10708" # Asegúrate de que `var.vpc_id` esté definido

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Sustituye por el rango de IPs que necesites permitir
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}
############ SG FRONTEND ###########
resource "aws_security_group" "ecs_frontend_sg" {
  name        = "ecs-frontend-sg"
  description = "Allow traffic from ALB to ECS Frontend"
  vpc_id      = "vpc-053917e74d7c10708"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # Permite solo tráfico desde el ALB
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


############ SG RDS ###########
/*resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow access to RDS from ECS tasks"
  vpc_id      = "vpc-053917e74d7c10708"

  ingress {
    from_port   = 3306
    to_port     = 3306
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

resource "aws_security_group_rule" "allow_mysql_access" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.rds_sg.id
  cidr_blocks       = ["189.28.91.56/32"]
}*/


/*resource "aws_security_group" "ecs_task_sg" {
  name        = "ecs-task-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = "vpc-053917e74d7c10708" # Ajusta con tu VPC

  ingress {
    description      = "Allow HTTP traffic from ALB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb_sg.id] # Permitir tráfico solo desde el ALB
  }

  ingress {
    description = "Allow traffic from ALB for python-app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ECS Task Security Group"
  }
}*/
