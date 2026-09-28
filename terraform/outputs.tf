output "ecr_repository_url" {
  description = "URL completa del repositorio ECR creado."
  value       = aws_ecr_repository.app_repo.repository_url
}

output "ecr_repository_registry_id" {
  description = "ID del registro de ECR (AWS Account ID)."
  value       = aws_ecr_repository.app_repo.registry_id
}

output "jenkins_user_access_key_id" {
  description = "AWS Access Key ID para configurar en las credenciales de Jenkins."
  value       = aws_iam_access_key.jenkins_user_key.id
}

output "jenkins_user_secret_access_key" {
  description = "AWS Secret Access Key para configurar en las credenciales de Jenkins."
  value       = aws_iam_access_key.jenkins_user_key.secret
  sensitive   = true
}