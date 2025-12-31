pipeline {
  agent {
    kubernetes {
      cloud 'eks-agent'
      inheritFrom 'jenkins-kaniko-agent'
      defaultContainer 'jnlp'
    }
  }

  environment {
    IMAGE_NAME = "kamalakar2210/board_game"
    IMAGE_TAG  = "${BUILD_NUMBER}"

    ARGO_REPO  = "github.com/kamalakar22/argo-deploy.git"
    ARGO_DIR   = "argo-deploy"
    MANIFESTS  = "manifests"

    TRIVY_DB_REPOSITORY       = "docker.io/kamalakar2210/trivy-db"
    TRIVY_JAVA_DB_REPOSITORY  = "docker.io/kamalakar2210/trivy-java-db"
  }

  stages {

    stage('Verify Agent') {
      steps {
        sh '''
          echo "=== VERIFY AGENT ==="
          whoami
          mvn -v
          trivy --version || true
        '''
      }
    }

    stage('Maven Clean Install') {
      steps {
        sh '''
          echo "=== MAVEN BUILD ==="
          mvn clean install
        '''
      }
    }

    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv('sonarqube') {
          sh '''
            echo "=== SONARQUBE SCAN ==="
            mvn sonar:sonar \
              -Dsonar.projectKey=board-game \
              -Dsonar.projectName=board-game
          '''
        }
      }
    }

    stage('Trivy FS Scan & SBOM') {
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
          sh '''
            echo "=== TRIVY FS SCAN ==="
            mkdir -p trivy-reports sbom

            trivy fs \
              --format table \
              --output trivy-reports/fs-vuln.txt .

            trivy fs \
              --scanners vuln,license \
              --format cyclonedx \
              --output sbom/sbom-fs.json .
          '''
        }
      }
    }

    stage('Kaniko Build & Push') {
      steps {
        container('kaniko') {
          sh '''
            echo "=== KANIKO BUILD & PUSH ==="
            /kaniko/executor \
              --context /workspace \
              --dockerfile Dockerfile \
              --destination ${IMAGE_NAME}:${IMAGE_TAG} \
              --destination ${IMAGE_NAME}:latest
          '''
        }
      }
    }

    stage('Prepare Trivy Template') {
      steps {
        sh '''
          mkdir -p trivy-templates trivy-reports
          curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl \
            -o trivy-templates/html.tpl
        '''
      }
    }

    stage('Trivy Image Scan (NON-BLOCKING)') {
      steps {
        sh '''
          echo "=== TRIVY IMAGE SCAN ==="
          trivy image \
            ${IMAGE_NAME}:${IMAGE_TAG} \
            --severity LOW,MEDIUM,HIGH,CRITICAL \
            --ignore-unfixed \
            --no-progress \
            --format template \
            --template @trivy-templates/html.tpl \
            --output trivy-reports/trivy-image-report.html || true
        '''
      }
    }

    stage('Update ArgoCD Manifests') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'github-pat',
          usernameVariable: 'GIT_USER',
          passwordVariable: 'GIT_TOKEN'
        )]) {
          sh '''
            echo "=== UPDATE ARGOCD MANIFESTS ==="
            rm -rf ${ARGO_DIR}

            git clone https://${GIT_USER}:${GIT_TOKEN}@${ARGO_REPO}
            cd ${ARGO_DIR}/${MANIFESTS}

            sed -i "s|image: .*board_game.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" deploy.yaml

            git config user.name "Jenkins CI"
            git config user.email "jenkins@ci.local"

            git add deploy.yaml
            git commit -m "ci: update board_game image to ${IMAGE_TAG}" || echo "No changes"
            git push origin main
          '''
        }
      }
    }

  } // end stages

  post {
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: '''
        trivy-reports/*.html,
        trivy-reports/*.txt,
        sbom/*.json
      '''
      echo "Build #: ${BUILD_NUMBER}"
      echo "Result : ${currentBuild.currentResult}"
    }

    success {
      echo "PIPELINE SUCCESS – ArgoCD will sync automatically"
    }

    failure {
      echo "PIPELINE FAILED"
    }
  }
}
