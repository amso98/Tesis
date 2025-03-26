resource "aws_db_instance" "mariadb_instance" {
  allocated_storage        = 20
  engine                   = "mariadb"
  engine_version           = "10.6"        # Cambiar a una versión compatible
  instance_class           = "db.t3.micro" # Clase de instancia compatible
  db_name                  = "medic"
  username                 = "root"
  password                 = "rootpassword"
  port                     = 3306
  publicly_accessible      = true
  vpc_security_group_ids   = [aws_security_group.rds_sg.id]
  skip_final_snapshot      = true
  delete_automated_backups = true

  /*# Opcional: Habilitar backups
  backup_retention_period = 7
  storage_encrypted       = true*/
}