resource "aws_ecs_cluster" "app_cluster" {
  name = "clinic-ms-cluster"
}
##################### PYTHON-APP ######################
resource "aws_ecs_service" "python_app_service" {
  name            = "python-app-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.python_app_task.arn
  desired_count   = 1 # Puedes aumentar el número de instancias de tarea si es necesario
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-02b0cdcaa2b63c717", "subnet-0c2cba9a1b375e50b", "subnet-06299c7a0d12af21a"]
    security_groups  = [aws_security_group.ecs_sg.id] # Ajusta el Security Group
    assign_public_ip = true                           # Puedes usar true si deseas una IP pública
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.python_app_target_group.arn
    container_name   = "python-app-container"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener_rule.backend_rule] # Asegura que el ALB esté configurado antes de crear el servicio
}

resource "aws_ecs_task_definition" "python_app_task" {
  family                   = "python-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"  # Ajusta según tus necesidades
  memory                   = "1024" # Ajusta según tus necesidades
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "python-app-container"                                                       # Asegúrate de que el nombre aquí coincida con el del servicio ECS
    image     = "396608805514.dkr.ecr.us-east-2.amazonaws.com/my-ecr-repo:python-app-latest" # Asegúrate de que esta imagen esté disponible en ECR
    essential = true
    memory    = 512
    cpu       = 256
    portMappings = [
      {
        containerPort = 5000
        hostPort      = 5000
        protocol      = "tcp"
      }
    ]
    environment = [
      { name = "DB_HOST", value = "mariadb" },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_USER", value = "root" },
      { name = "DB_PASSWORD", value = "root" },
      { name = "DB_NAME", value = "medic" }
    ]
    /*healthCheck = {
      "command"     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"] //["CMD", "curl", "-f", "http://localhost:5000/health"] # Asegúrate de que tu contenedor tenga una ruta de salud /health
      "interval"    = 30
      "timeout"     = 5
      "retries"     = 3
      "startPeriod" = 30
    }*/
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/clinic-ms-logs"
        "awslogs-region"        = "us-east-2"
        "awslogs-stream-prefix" = "python-app"
      }
    }
  }])
}
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/clinic-ms-logs"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Añadir políticas para estos roles
resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name = "ecs-execution-role-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ecr:us-east-2:396608805514:repository/my-ecr-repo" # Ajusta con tu arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "ecs-task-role-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ecr:us-east-2:396608805514:repository/my-ecr-repo" # Ajusta con tu ECR
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" # Asegúrate de usar un policy válido
  role       = aws_iam_role.ecs_execution_role.name
}


resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

##################### PHP MY ADMIN #########################
resource "aws_ecs_service" "phpmyadmin_service" {
  name            = "phpmyadmin-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.phpmyadmin_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-02b0cdcaa2b63c717", "subnet-0c2cba9a1b375e50b", "subnet-06299c7a0d12af21a"]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true # Exponer el contenedor directamente
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.php-myadmin.arn
    container_name   = "phpmyadmin-container"
    container_port   = 80
  }
}

resource "aws_ecs_task_definition" "phpmyadmin_task" {
  family                   = "phpmyadmin-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"  # Ajusta según tus necesidades
  memory                   = "1024" # Ajusta según tus necesidades
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "phpmyadmin-container"
    image     = "396608805514.dkr.ecr.us-east-2.amazonaws.com/my-ecr-repo:phpmyadmin-latest" # Imagen ECR
    essential = true
    memory    = 512
    cpu       = 256
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }
    ]
    environment = [
      { name = "PMA_HOST", value = aws_db_instance.mariadb_instance.endpoint }, # Sustituye "rds-endpoint" por el endpoint de RDS
      { name = "PMA_PORT", value = "3306" },
      { name = "MYSQL_ROOT_PASSWORD", value = "rootpassword" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/clinic-ms-logs"
        "awslogs-region"        = "us-east-2"
        "awslogs-stream-prefix" = "phpmyadmin"
      }
    }
  }])
}

##################### FRONTEND ######################
resource "aws_ecs_service" "frontend_service" {
  name            = "frontend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.frontend_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-02b0cdcaa2b63c717", "subnet-0c2cba9a1b375e50b", "subnet-06299c7a0d12af21a"]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend-container"
    container_port   = 80
  }
}

resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "frontend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend-container"
      image     = "396608805514.dkr.ecr.us-east-2.amazonaws.com/my-ecr-repo:frontend-latest"
      essential = true
      memory    = 512
      cpu       = 256
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/clinic-ms-logs"
          "awslogs-region"        = "us-east-2"
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}
