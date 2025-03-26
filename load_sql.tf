/*resource "null_resource" "initialize_db" {
  provisioner "local-exec" {
    command = <<EOT
      mysql -h ${aws_db_instance.mariadb_instance.address} \
            -P 3306 \
            -u root \
            -p'root' \
            medic < ./medic.sql
    EOT
  }

  depends_on = [aws_db_instance.mariadb_instance]
}
*/