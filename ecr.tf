resource "aws_ecr_repository" "ECR_test" {
  name = "my-ecr-repo"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}