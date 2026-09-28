pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    component: jenkins-agent
spec:
  containers:
  - name: python
    image: python:3.11-slim
    command:
    - cat
    tty: true
  - name: docker-trivy
    image: docker:24.0-dind
    securityContext:
      privileged: true
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /var/run/docker.sock
      name: docker-sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }

    environment {
        AWS_REGION          = 'us-east-1'
        AWS_ACCOUNT_ID      = '123456789012' // Reemplazar con tu ID real de AWS
        ECR_REPO_NAME       = 'devops-enterprise-api'
        IMAGE_NAME          = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
        BUILD_TAG           = "build-${BUILD_NUMBER}"
        AWS_CREDENTIALS_ID  = 'aws-ecr-credentials' // ID configurado en Jenkins Credentials Store
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        ansiColor('xterm')
    }

    stages {

        stage('1. Code Analysis & Unit Tests') {
            steps {
                container('python') {
                    sh '''
                        echo "=== [CI] Ejecutando Pruebas Unitarias ==="
                        python -m venv venv
                        . venv/bin/activate
                        pip install --upgrade pip
                        pip install -r app/requirements.txt
                        
                        # Ejecutar suite de pruebas unitarias con Pytest
                        pytest tests/ --verbose --junitxml=test-results.xml
                    '''
                }
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        stage('2. Build Docker Image') {
            steps {
                container('docker-trivy') {
                    sh '''
                        echo "=== [CI] Construyendo Imagen Docker ==="
                        docker build -t ${IMAGE_NAME}:${BUILD_TAG} -t ${IMAGE_NAME}:latest .
                    '''
                }
            }
        }

        stage('3. Security Scan (Trivy DevSecOps)') {
            steps {
                container('docker-trivy') {
                    sh '''
                        echo "=== [DevSecOps] Escaneando Vulnerabilidades con Trivy ==="
                        # Descargar e instalar binario oficial de Trivy
                        wget https://github.com/aquasecurity/trivy/releases/download/v0.48.3/trivy_0.48.3_Linux-64bit.tar.gz
                        tar zxvf trivy_0.48.3_Linux-64bit.tar.gz
                        
                        # Escanear imagen (Audita severidades HIGH y CRITICAL sin abortar la ejecución en dev)
                        ./trivy image --severity HIGH,CRITICAL --exit-code 0 ${IMAGE_NAME}:${BUILD_TAG}
                    '''
                }
            }
        }

        stage('4. AWS ECR Authentication & Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.AWS_CREDENTIALS_ID,
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    container('docker-trivy') {
                        sh '''
                            echo "=== [CD] Autenticando con AWS ECR ==="
                            # Instalar AWS CLI en el contenedor efímero
                            apk add --no-cache aws-cli
                            
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                            
                            echo "=== [CD] Publicando Imagen en AWS ECR ==="
                            docker push ${IMAGE_NAME}:${BUILD_TAG}
                            docker push ${IMAGE_NAME}:latest
                        '''
                    }
                }
            }
        }

        stage('5. Kubernetes Deployment (Minikube)') {
            steps {
                container('docker-trivy') {
                    sh '''
                        echo "=== [CD] Desplegando en Kubernetes (Minikube) ==="
                        # Instalar kubectl
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl && mv kubectl /usr/local/bin/

                        # Crear Namespace y ConfigMap
                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/configmap.yaml

                        # Reemplazar la etiqueta de imagen en el manifiesto dinámicamente
                        sed -i "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" k8s/deployment.yaml
                        sed -i "s|BUILD_TAG|${BUILD_TAG}|g" k8s/deployment.yaml

                        # Aplicar Deployment y Service
                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml

                        # Confirmar el estado del despliegue (Rolling Update)
                        kubectl rollout status deployment/devops-enterprise-api -n dev --timeout=120s
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completado exitosamente. La API está corriendo en Minikube con la imagen ${BUILD_TAG}."
        }
        failure {
            echo "❌ El pipeline falló en una de sus etapas. Revisa los logs anteriores."
        }
    }
}