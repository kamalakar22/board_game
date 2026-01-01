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

    /* =========================
       SHARED CACHE LOCATIONS
       ========================= */
    MAVEN_OPTS        = "-Dmaven.repo.local=/cache/maven"
    NPM_CONFIG_CACHE  = "/cache/npm"
    TRIVY_CACHE_DIR   = "/cache/trivy"

    TRIVY_DB_REPOSITORY      = "docker.io/kamalakar2210/trivy-db"
    TRIVY_JAVA_DB_REPOSITORY = "docker.io/kamalakar2210/trivy-java-db"
  }

  stages {

    stage('Verify Agent') {
      steps {
        sh '''
          whoami
          mvn -v
          trivy --version || true
          echo "Cache directory:"
          ls -l /cache || true
        '''
      }
    }

    /* =========================
       Maven Build (ONLY ONCE)
       ========================= */
    stage('Maven Build') {
      steps {
        sh '''
          echo "=== MAVEN BUILD (WITH CACHE) ==="
          mvn clean package -DskipTests
        '''
      }
    }

    /* =========================
       SonarQube Scan (ANALYSIS ONLY)
       ========================= */
    stage('SonarQube Scan') {
      steps {
        withSonarQubeEnv('sonarqube') {
          sh '''
            echo "=== SONARQUBE ANALYSIS (REUSE MAVEN CACHE) ==="

            mvn -DskipTests \
                -Dsonar.projectKey=board-game \
                -Dsonar.projectName=board-game \
                -Dsonar.java.binaries=target/classes \
                org.sonarsource.scanner.maven:sonar-maven-plugin:5.5.0.6356:sonar
          '''
        }
      }
    }

    /* ==========================
       Trivy FS Scan & SBOM
       ========================= */
    stage('Trivy FS Scan & SBOM') {
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
          sh '''
            mkdir -p trivy-reports sbom

            trivy fs \
              --cache-dir ${TRIVY_CACHE_DIR} \
              --scanners vuln \
              --format table \
              --output trivy-reports/fs-vuln.txt .

            trivy fs \
              --cache-dir ${TRIVY_CACHE_DIR} \
              --scanners vuln,license \
              --format cyclonedx \
              --output sbom/sbom-fs.json .
          '''
        }
      }
    }

    /* =========================
       Kaniko Build & Push
       ========================= */
    stage('Kaniko Build & Push') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --context /workspace \
              --dockerfile Dockerfile \
              --destination ${IMAGE_NAME}:${IMAGE_TAG} \
              --destination ${IMAGE_NAME}:latest \
              --cache=true \
              --cache-dir=/cache/kaniko
          '''
        }
      }
    }

    /* =========================
       Update ArgoCD
       ========================= */
    stage('Update ArgoCD Manifests') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'github-pat',
          usernameVariable: 'GIT_USER',
          passwordVariable: 'GIT_TOKEN'
        )]) {
          sh '''
            rm -rf ${ARGO_DIR}
            git clone https://${GIT_USER}:${GIT_TOKEN}@${ARGO_REPO}
            cd ${ARGO_DIR}/${MANIFESTS}

            sed -i "s|image: .*board_game.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" deploy.yaml

            git config user.name "Jenkins CI"
            git config user.email "jenkins@ci.local"
            git add deploy.yaml
            git commit -m "ci: update board_game image to ${IMAGE_TAG}" || true
            git push origin main
          '''
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts allowEmptyArchive: true, artifacts: '''
        trivy-reports/*,
        sbom/*.json
      '''
      echo "Result : ${currentBuild.currentResult}"
    }
  }
}
