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
	
	// Trivy DB mirrors (already pushed by you)
    TRIVY_DB_REPOSITORY      = "docker.io/kamalakar2210/trivy-db"
    TRIVY_JAVA_DB_REPOSITORY = "docker.io/kamalakar2210/trivy-java-db"

    
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
            mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
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

            # HTML report
            trivy fs \
              --server ${TRIVY_SERVER_URL} \
              --format html \
              --output trivy-reports/fs-vuln.html .

            # SBOM in CycloneDX format
            trivy fs \
              --server ${TRIVY_SERVER_URL} \
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

   /* =================================================
       Prepare Trivy HTML Template
       ================================================= */
    stage('Prepare Trivy Template') {
      steps {
        sh '''
          mkdir -p trivy-templates trivy-reports

          if [ ! -f trivy-templates/html.tpl ]; then
            curl -fsSL \
              https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl \
              -o trivy-templates/html.tpl
          fi
        '''
      }
    }

    /* =================================================
       Trivy Image Scan (NON-BLOCKING, ALL SEVERITIES)
       ================================================= */
    stage('Trivy Image Scan (NON-BLOCKING)') {
      steps {
        sh '''
          echo "=== TRIVY IMAGE SCAN (NON-BLOCKING) ==="

          trivy image \
            --scanners vuln \
            --input image.tar \
            --severity LOW,MEDIUM,HIGH,CRITICAL \
            --ignore-unfixed \
            --no-progress \
            --format template \
            --template @trivy-templates/html.tpl \
            --output trivy-reports/trivy-image-report.html || true
        '''
      }
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

            echo "Updating image to ${IMAGE_NAME}:${IMAGE_TAG}"

            sed -i "s|image: .*board_game.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" deploy.yaml

            git config user.name "Jenkins CI"
            git config user.email "jenkins@ci.local"

            git add deploy.yaml

            git commit -m "ci: update board_game image to ${IMAGE_TAG}" || echo "No changes to commit"

            git push origin main
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: '''
        trivy-reports/*.html,
        sbom/*.json
      '''
      echo "Build #: ${BUILD_NUMBER}"
      echo "Result : ${currentBuild.currentResult}"
    }

    success {
      echo "✅ PIPELINE SUCCESS – Argo CD will sync automatically"
    }

    failure {
      echo "❌ PIPELINE FAILED"
    }
  }
}
