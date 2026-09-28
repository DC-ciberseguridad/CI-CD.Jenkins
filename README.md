
# 🏗️ Laboratorio # 10: 🚀 Enterprise DevOps Pipeline: Jenkins on Kubernetes with Dynamic Agents & AWS ECR

Este proyecto implementa una **plataforma de Integración y Entrega Continua (CI/CD) de nivel empresarial** utilizando una arquitectura híbrida. La infraestructura de ejecución corre sobre un clúster local de **Kubernetes (Minikube)** con **Jenkins** configurado mediante **agentes dinámicos (Pods efímeros)**.

El ciclo de vida del software gestiona una **API REST moderna (Python/FastAPI)**, audita su seguridad mediante escaneo de imágenes con **Trivy (DevSecOps)**, almacena las imágenes de contenedor compiladas en un registro privado en la nube (**AWS ECR**) aprovisionado con **Terraform**, y orquesta un despliegue sin interrupciones (*Rolling Update*) dentro del clúster.

## 🎯 Finalidad Principal

    1. Aprovisionar la infraestructura de registro privado en AWS utilizando Terraform (siguiendo buenas prácticas de menor privilegio con IAM y estado almacenado o administrado de forma segura).
    
    2. Desplegar Jenkins en Kubernetes utilizando Helm y configurar el plugin de Kubernetes para la creación de Worker Pods dinámicos bajo demanda.
    
    3. Construir una API REST completa (Python/FastAPI) con suites de pruebas unitarias (pytest) y endpoints de salud (/health) aptos para comprobaciones de estado de Kubernetes (Liveness/Readiness Probes).
    
    4. Implementar un Pipeline de DevSecOps (Jenkinsfile declarativo) que ejecute pruebas automáticas, escaneo SAST/de imágenes de contenedor y publicación autenticada en AWS ECR.
    
    5. Orquestar la Entrega Continua (CD) automatizada desplegando y actualizando los manifiestos de Kubernetes (Deployment, Service, ConfigMap) dentro de Minikube.

## Requisitos
    • Docker Desktop o Engine
    • Minikube
    • Helm
    • OpenTofu o Terraform
    • AWS CLI
    • Repositorio en GitHub

## 📁 Estructura del Proyecto
```
CI-CD.Jenkins/
├── README.md                          # Documentación completa y guía de ejecución
├── Jenkinsfile                        # Pipeline Declarativo de CI/CD (Jenkins-as-Code)
├── terraform/                         # Infraestructura como Código (AWS)
│   ├── main.tf                        # Módulo principal para AWS ECR y políticas IAM
│   ├── variables.tf                   # Variables de entorno de Terraform
│   ├── outputs.tf                     # Salidas (URL del repositorio ECR)
│   └── terraform.tfvars               # Configuración de variables locales
├── k8s/                               # Manifiestos de Kubernetes de la Aplicación
│   ├── namespace.yaml                 # Namespace exclusivo 'dev'
│   ├── configmap.yaml                 # Variables de entorno de la app
│   ├── deployment.yaml                # Configuración del Deployment (Pods, Probes)
│   └── service.yaml                   # Servicio de exposición (NodePort / ClusterIP)
├── jenkins/                           # Configuración y Helm valores para Jenkins
│   └── values.yaml                    # Valores personalizados de Helm para Jenkins en K8s
└── app/                               # Código Fuente de la API REST (Python)
    ├── app/
    │   └── main.py                    # Endpoints FastAPI (/health, /api/v1/data)
    ├── tests/
    │   └── test_main.py               # Pruebas unitarias ejecutadas por Pytest
    ├── Dockerfile                     # Imagen optimizada multi-stage para la API
    └── requirements.txt               # Dependencias de la aplicación (FastAPI, uvicorn)
```

## 🚀 Plan de Ejecución Paso a Paso

### Paso 1: Iniciar el Clúster Local

Bash

minikube start

### Paso 2 — Aprovisionar Registros de AWS ECR con Terraform

Bash

cd terraform/
terraform init
terraform apply -auto-approve

Nota: Toma nota de los outputs jenkins_user_access_key_id y jenkins_user_secret_access_key (obtenlo ejecutando terraform output jenkins_user_secret_access_key).

### Paso 3 — Desplegar Jenkins en Kubernetes con Helm

Bash

cd ..
helm repo add jenkins [https://charts.jenkins.io](https://charts.jenkins.io)
helm repo update
helm install jenkins jenkins/jenkins -f jenkins/values.yaml -n jenkins --create-namespace

### Paso 4 — Obtener Credenciales de Jenkins y Acceder

1. Obtén la contraseña inicial del administrador de Jenkins:

Bash
kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode; echo

2. Redirige el puerto del servicio a tu máquina local:

Bash
kubectl port-forward svc/jenkins -n jenkins 8080:8080

3. Accede a http://localhost:8080 (Usuario: admin).

### Paso 5 — Configurar Credenciales de AWS en Jenkins

Ve a Manage Jenkins -> Credentials -> System -> Global credentials.

Añade credenciales de tipo Username with password:

 • ID: aws-ecr-credentials

 • Username: <jenkins_user_access_key_id>

 • Password: <jenkins_user_secret_access_key>

### Paso 6 — Configurar el Secret de Autenticación de ECR en Kubernetes

Ejecuta el siguiente comando para permitir que Kubernetes descargue imágenes privadas de AWS ECR en el namespace dev:

Bash

kubectl create namespace dev

kubectl create secret docker-registry aws-ecr-secret \
  --docker-server=<TU_AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  -n dev

### 🔄 Ejecución del Pipeline (CI/CD)

1. En Jenkins, crea un nuevo Pipeline Job llamado devops-enterprise-api-pipeline.
2. En la sección Pipeline, selecciona Pipeline script from SCM.
3. Selecciona Git, ingresa la URL de GitHub del repositorio y especifica la rama principal (*/main).
4. Confirma que el Script Path apunte a Jenkinsfile.
5. Guarda y haz clic en Build Now.

## 🧪 Comprobación y Validación del Proyecto

Una vez que el pipeline finalice con éxito, valida el despliegue de la API en el clúster:

Bash
# 1. Verificar los pods desplegados
kubectl get pods -n dev

# 2. Verificar el rollout de la aplicación
kubectl rollout status deployment/devops-enterprise-api -n dev

# 3. Acceder a los endpoints de la API
minikube service devops-enterprise-api-svc -n dev
Probar los endpoints en el navegador o vía curl:

 • Salud de la app (Liveness Probe): http://<node-ip>:<node-port>/health
 • Disponibilidad de servicio (Readiness Probe): http://<node-ip>:<node-port>/ready
 • Documentación OpenAPI (Swagger): http://<node-ip>:<node-port>/docs


## 🧹 Limpieza de Recursos

Para evitar cargos innecesarios en AWS o consumo de memoria local:

Bash

# 1. Destruir infraestructura en AWS
cd terraform/
terraform destroy -auto-approve

# 2. Eliminar Jenkins y la app en Kubernetes
helm uninstall jenkins -n jenkins
kubectl delete namespace dev jenkins

# 3. Detener Minikube
minikube stop