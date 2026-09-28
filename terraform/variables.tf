variable "aws_region" {
  type        = string
  description = "Región de AWS donde se desplegarán los recursos."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nombre base del proyecto para naming convetions."
  default     = "lab10-jenkins-devops"
}

variable "environment" {
  type        = string
  description = "Entorno de despliegue (dev, qa, prod)."
  default     = "dev"
}

variable "ecr_repository_name" {
  type        = string
  description = "Nombre del repositorio privado en AWS ECR."
  default     = "devops-enterprise-api"
}

variable "image_tag_mutability" {
  type        = string
  description = "Permite o previene la sobreescritura de tags de imagen (MUTABLE o IMMUTABLE)."
  default     = "MUTABLE"
}