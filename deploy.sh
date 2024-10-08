#!/bin/bash

# Variables
AWS_REGION="us-east-1"
APP_NAME="mean-user-registration"
ECR_REPOSITORY_FRONTEND="${APP_NAME}-frontend"
ECR_REPOSITORY_BACKEND="${APP_NAME}-backend"

DOCKERFILE_FRONTEND_PATH="MEAN-Stack-User-Registration-Front-End/Angular6"
DOCKERFILE_BACKEND_PATH="MEAN-Stack-User-Registration---Back-End/Project"

# Función para crear el ECR
create_ecr_repository() {
    echo "Creando repositorio ECR para el front-end..."
    aws ecr create-repository --repository-name "$ECR_REPOSITORY_FRONTEND" --region $AWS_REGION

    echo "Creando repositorio ECR para el back-end..."
    aws ecr create-repository --repository-name "$ECR_REPOSITORY_BACKEND" --region $AWS_REGION
}

# Función para construir y subir las imágenes
build_and_push_images() {
    # Iniciar sesión en ECR
    $(aws ecr get-login --no-include-email --region $AWS_REGION)

    # Construir y subir imagen del front-end
    echo "Construyendo imagen del front-end..."
    docker build -t "$ECR_REPOSITORY_FRONTEND" "$DOCKERFILE_FRONTEND_PATH"
    docker tag "$ECR_REPOSITORY_FRONTEND:latest" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_FRONTEND:latest"
    docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_FRONTEND:latest"

    # Construir y subir imagen del back-end
    echo "Construyendo imagen del back-end..."
    docker build -t "$ECR_REPOSITORY_BACKEND" "$DOCKERFILE_BACKEND_PATH"
    docker tag "$ECR_REPOSITORY_BACKEND:latest" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_BACKEND:latest"
    docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_BACKEND:latest"
}

# Función para ejecutar Terraform
run_terraform() {
    echo "Inicializando Terraform..."
    terraform init

    echo "Ejecutando Terraform apply..."
    terraform apply -auto-approve

    # Obtener la URL del ALB
    ALB_DNS=$(terraform output -raw frontend_alb_dns)
    echo "El front-end está disponible en: http://$ALB_DNS"
}

# Main
create_ecr_repository
build_and_push_images
run_terraform
