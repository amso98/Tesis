
/*# Generar la carpeta build del frontend
resource "null_resource" "build_frontend" {
  provisioner "local-exec" {
    command = "cd ~/clinic_ms/frontend && npm run build"
  }
}

# Subir los archivos generados a S3
resource "null_resource" "upload_frontend_to_s3" {
  depends_on = [
    aws_s3_bucket.frontend_bucket,
    null_resource.build_frontend  # Asegura que la carpeta build esté lista
  ]

  provisioner "local-exec" {
    command = "aws s3 sync ~/clinic_ms/frontend/build s3://${aws_s3_bucket.frontend_bucket.bucket} --delete"
  }
}*/