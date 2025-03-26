#!/bin/bash
set -e
cd ../../clinic_ms/

# Definir variables
AWS_ACCOUNT_ID="396608805514"
REGION="us-east-2"
ECR_REPO="my-ecr-repo"  # Ajusta el nombre del repositorio de ECR si es necesario

# Construir las imágenes de Docker Compose
docker-compose build

# Etiquetar las imágenes construidas para ECR
docker tag tesis-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:frontend-latest
docker tag tesis-python-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:python-app-latest
docker tag tesis-phpmyadmin:latest $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:phpmyadmin-latest

# Iniciar sesión en ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Subir las imágenes a ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:frontend-latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:python-app-latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:phpmyadmin-latest

echo "Imágenes frontend-latest y python-app-latest subidas a ECR exitosamente!"