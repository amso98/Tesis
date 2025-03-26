output "rds_endpoint" {
  value = aws_db_instance.mariadb_instance.endpoint
}