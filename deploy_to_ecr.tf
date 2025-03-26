resource "null_resource" "deploy_to_ecr" {
  provisioner "local-exec" {
    command = "./deploy-to-ecr.sh"
  }

  depends_on = [aws_ecr_repository.ECR_test] # Asegúrate de que esto dependa de tu ECR
}