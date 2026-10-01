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
  - name: jnlp
    image: jenkins/inbound-agent:4.11.2-1-alpine
    imagePullPolicy: IfNotPresent
  - name: python
    image: python:3.11-slim
    command:
    - cat
    tty: true
  - name: docker-trivy
    image: docker:24.0-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    - name: DOCKER_HOST
      value: "tcp://localhost:2375"
    command:
    - cat
    tty: true
'''
        }
    }

    environment {
        AWS_REGION          = 'us-east-1'
        AWS_ACCOUNT_ID      = '270876217576'
        ECR_REPO_NAME       = 'devops-enterprise-api'
        IMAGE_NAME          = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
        BUILD_TAG           = "build-${BUILD_NUMBER}"
        AWS_CREDENTIALS_ID  = 'aws-ecr-credentials'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
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
                        
                        export PYTHONPATH=$PYTHONPATH:$(pwd)/app
                        
                        pytest app/tests/ --verbose --junitxml=test-results.xml
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'test-results.xml', allowEmptyArchive: true
                }
            }
        }

        stage('2. Build Docker Image') {
            steps {
                container('docker-trivy') {
                    sh '''
                        echo "=== [CI] Iniciando Daemon de Docker ==="
                        dockerd-entrypoint.sh --tls=false > /dev/null 2>&1 &
                        sleep 3

                        echo "=== [CI] Construyendo Imagen Docker ==="
                        docker build -t ${IMAGE_NAME}:${BUILD_TAG} -t ${IMAGE_NAME}:latest -f app/Dockerfile app/
                    '''
                }
            }
        }

        stage('3. Security Scan (Trivy DevSecOps)') {
    steps {
        container('docker-trivy') {
            sh '''
                echo "=== [DevSecOps] Escaneando Vulnerabilidades con Trivy ==="
                
                # Instalar Trivy de forma dinámica usando el instalador oficial
                wget -qO- https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                
                # Ejecutar el escaneo sobre la imagen construida
                trivy image --severity HIGH,CRITICAL 270876217576.dkr.ecr.us-east-1.amazonaws.com/devops-enterprise-api:latest
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
                    echo "=== [CD] Instalando Helper Oficial de Amazon ECR (Binario Go) ==="
                    # Descargar e instalar el binario estático oficial
                    wget -q https://amazon-ecr-credential-helper-releases.s3.us-east-1.amazonaws.com/0.8.0/linux-amd64/docker-credential-ecr-login -O /usr/local/bin/docker-credential-ecr-login
                    chmod +x /usr/local/bin/docker-credential-ecr-login

                    echo "=== [CD] Configurando credenciales de Docker para ECR ==="
                    mkdir -p ~/.docker
                    echo '{"credsStore": "ecr-login"}' > ~/.docker/config.json

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
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl && mv kubectl /usr/local/bin/

                        kubectl apply -f k8s/namespace.yaml
                        kubectl apply -f k8s/configmap.yaml

                        sed -i "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" k8s/deployment.yaml
                        sed -i "s|BUILD_TAG|${BUILD_TAG}|g" k8s/deployment.yaml

                        kubectl apply -f k8s/deployment.yaml
                        kubectl apply -f k8s/service.yaml

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