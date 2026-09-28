terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Lab         = "Lab10-Jenkins-K8s"
    }
  }
}

# -----------------------------------------------------------------------------
# 1. AWS ECR REPOSITORY
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.image_tag_mutability

  # Escaneo automático de vulnerabilidades al hacer push (Seguridad DevSecOps)
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Regla de ciclo de vida: Mantiene solo las últimas 5 imágenes para ahorrar espacio en la Capa Gratuita
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Conservar solo las últimas 5 imágenes etiquetadas"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "build"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Eliminar imágenes sin etiqueta de más de 3 días"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 2. IAM POLICY & USER PARA JENKINS (Mínimo Privilegio)
# -----------------------------------------------------------------------------
resource "aws_iam_user" "jenkins_ci_user" {
  name = "${var.project_name}-jenkins-ci-user"
}

# Política IAM que otorga token de autorización global y permisos de Push/Pull en el ECR específico
resource "aws_iam_policy" "jenkins_ecr_policy" {
  name        = "${var.project_name}-ecr-policy"
  description = "Política de mínimo privilegio para permitir a Jenkins subir imágenes a ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = aws_ecr_repository.app_repo.arn
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_attach" {
  user       = aws_iam_user.jenkins_ci_user.name
  policy_arn = aws_iam_policy.jenkins_ecr_policy.arn
}

# Clave de acceso programático para configurar como Secret Credential en Jenkins
resource "aws_iam_access_key" "jenkins_user_key" {
  user = aws_iam_user.jenkins_ci_user.name
}