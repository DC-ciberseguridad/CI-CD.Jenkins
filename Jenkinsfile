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
  volumes:
  - name: shared-tmp
    emptyDir: {}
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:4.11.2-1-alpine
    imagePullPolicy: IfNotPresent
  - name: python
    image: python:3.11-slim
    command:
    - cat
    tty: true
  - name: aws-cli
    image: amazon/aws-cli:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - name: shared-tmp
      mountPath: /shared-tmp
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
    volumeMounts:
    - name: shared-tmp
      mountPath: /shared-tmp
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
                    
                    # Instalar Trivy si no está presente
                    if ! command -v trivy &> /dev/null; then
                        wget -qO- https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                    fi

                    # Descargar la base de datos con reintentos e indicar un mirror alternativo si gcr.io falla
                    trivy image \
                    --db-repository ghcr.io/aquasecurity/trivy-db \
                    --severity HIGH,CRITICAL \
                    ${IMAGE_NAME}:latest
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
                    container('aws-cli') {
                        sh '''
                            echo "=== [CD] Obteniendo Token de ECR con AWS CLI ==="
                            aws ecr get-login-password --region ${AWS_REGION} > /shared-tmp/ecr_pass.txt
                        '''
                    }

                    container('docker-trivy') {
                        sh '''
                            echo "=== [CD] Autenticando Docker con ECR ==="
                            cat /shared-tmp/ecr_pass.txt | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                            rm -f /shared-tmp/ecr_pass.txt

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
                withCredentials([usernamePassword(
                    credentialsId: env.AWS_CREDENTIALS_ID,
                    usernameVariable: 'AWS_ACCESS_KEY_ID',
                    passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                )]) {
                    // 1. Obtener el token con el contenedor oficial aws-cli
                    container('aws-cli') {
                        sh '''
                            echo "=== [CD] Obteniendo Token de ECR para K8s ==="
                            aws ecr get-login-password --region ${AWS_REGION} > /shared-tmp/ecr_k8s_token.txt
                        '''
                    }

                    // 2. Aplicar manifiestos y crear el secret en el contenedor docker-trivy
                    container('docker-trivy') {
                        sh '''
                            echo "=== [CD] Desplegando en Kubernetes (Minikube) ==="
                            
                            # Instalar curl solo si no está presente
                            if ! command -v curl &> /dev/null; then
                                apk add --no-cache curl
                            fi

                            # Descargar kubectl
                            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                            chmod +x kubectl && mv kubectl /usr/local/bin/

                            # Leer token y crear/actualizar el secret regcred en el namespace dev
                            ECR_TOKEN=$(cat /shared-tmp/ecr_k8s_token.txt)
                            rm -f /shared-tmp/ecr_k8s_token.txt

                            kubectl create secret docker-registry regcred \
                            --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
                            --docker-username=AWS \
                            --docker-password="${ECR_TOKEN}" \
                            -n dev --dry-run=client -o yaml | kubectl apply -f -

                            # Aplicar ConfigMap
                            kubectl apply -f k8s/configmap.yaml -n dev

                            # Reemplazar variables en deployment.yaml
                            sed -i "s|<AWS_ACCOUNT_ID>|${AWS_ACCOUNT_ID}|g" k8s/deployment.yaml
                            sed -i "s|BUILD_TAG|${BUILD_TAG}|g" k8s/deployment.yaml

                            # Aplicar Deployment y Service
                            kubectl apply -f k8s/deployment.yaml -n dev
                            kubectl apply -f k8s/service.yaml -n dev

                            # Esperar despliegue exitoso
                            kubectl rollout status deployment/devops-enterprise-api -n dev --timeout=300s
                        '''
                    }
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