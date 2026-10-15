// ===================================================================
// Ba?i 2 - Jenkins: CHUAN BI -> BUILD -> TEST -> PUSH -> PULL -> DEPLOY
// Du an: DevOPS-26-13 - Student Management System
// ===================================================================
// Jenkins chay trong container tren laptop, deploy nguoc ra chinh laptop
// qua /var/run/docker.sock. Ba nguyen tac:
//
// 1) BUILD MOT LAN cho moi kieng trac, KHONG build lai khi deploy.
//    Build bang docker compose vi du an co 3 service:
//      backend (Spring Boot) - frontend (nginx) - database (MSSQL 2022)
//
// 2) TEST TRUOC khi push: len stack, chay 8 smoke test bang ci/smoke-test.sh,
//    xong thi down de khong tranh cong port voi phien deploy cu.
//
// 3) PUSH len GHCR - PULL lai ve - DEPLOY tu image da pull
//    (khong build lai) -> deploy chac chan dung dung code da test.
// ===================================================================

pipeline {
  agent any

  environment {
    REGISTRY   = 'ghcr.io'
    // DUA theo ten repo GitHub (Viet thuong, khong dau cach)
    IMAGE_NAME = 'phuoctoan102334/devops-26-13'
    IMAGE      = "${REGISTRY}/${IMAGE_NAME}"

    // Credential kieu "Username with password":
    //   user     = ten GitHub
    //   password = Personal Access Token co quyen write:packages
    GHCR_CREDS = credentials('ghcr-credentials')

    // Ten compose project. Trung ten voi stack dang chay tren may nen
    // deploy thay the tai cho, khong sinh them stack trung cong port.
    COMPOSE_PROJECT = 'student-management-system'

    // Ba service trong docker-compose.yml
    SERVICES = 'backend frontend database'

    DEPLOY_FRONTEND_PORT = '3000'
    DEPLOY_BACKEND_PORT  = '8080'
    DEPLOY_DB_PORT       = '1433'
  }

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))   // giu 10 ban gan nhat de rollback
  }

  triggers {
    // Laptop khong co IP public nen GitHub khong goi webhook duoc
    // -> Jenkins tu hoi 2 phut/lan xem co commit moi khong.
    pollSCM('H/2 * * * *')
  }

  stages {

    // ---------- Chuẩn b? : tag + dang nhap registry ----------
    stage('Chuan bi') {
      steps {
        script {
          env.SHA_SHORT = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
        }

        echo "Commit     : ${env.SHA_SHORT}"
        echo "Image base : ${IMAGE}"
        sh 'docker compose version'
        sh 'git log -1 --oneline'

        // Dang nhap NGAY tu dau stage BUILD da can ghi cache len registry.
        // --password-stdin: token khong lan vao log hay danh sach tien trinh.
        sh '''
          echo "$GHCR_CREDS_PSW" | docker login ${REGISTRY} -u "$GHCR_CREDS_USR" --password-stdin
        '''
      }
    }

    // ---------- Buoc 1: BUILD ----------
    stage('1. BUILD') {
      steps {
        // --pull: lay image goc moi nhat; docker compose build xay dung
        // ca 3 service theo thu tu dependency (database -> backend -> frontend).
        sh '''
          set -e
          docker compose -p ${COMPOSE_PROJECT} build
          echo "=== Anh da build ==="
          docker images --format "{{.Repository}}:{{.Tag}}  {{.Size}}" \
            | grep "${COMPOSE_PROJECT}"
        '''
      }
    }

    // ---------- Buoc 2: TEST ----------
    stage('2. TEST') {
      steps {
        sh '''
          set -e
          docker compose -p ${COMPOSE_PROJECT} up -d

          echo "=== Cho backend san sang (toi da 180s) ==="
          for i in $(seq 1 60); do
            c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 \
                "http://host.docker.internal:${DEPLOY_BACKEND_PORT}/api/students" || true)
            if [ "$c" = "200" ]; then
              echo "backend OK sau $((i*3))s"
              break
            fi
            sleep 3
          done

          BACKEND_PORT=${DEPLOY_BACKEND_PORT} \
          FRONTEND_PORT=${DEPLOY_FRONTEND_PORT} \
          COMPOSE_PROJECT=${COMPOSE_PROJECT} \
            sh ci/smoke-test.sh

          # Xong test -> ha stack tam. Du lieu van con trong volume sqldata.
          docker compose -p ${COMPOSE_PROJECT} down
        '''
      }
    }

    // ---------- Buoc 3: PUSH ----------
    stage('3. PUSH') {
      steps {
        sh '''
          set -e
          for s in ${SERVICES}; do
            src="${COMPOSE_PROJECT}-${s}:latest"
            docker tag "${src}" "${IMAGE}-${s}:${SHA_SHORT}"
            docker tag "${src}" "${IMAGE}-${s}:latest"
            docker push "${IMAGE}-${s}:${SHA_SHORT}"
            docker push "${IMAGE}-${s}:latest"
          done
        '''
      }
    }

    // ---------- Buoc 4: PULL ----------
    stage('4. PULL') {
      steps {
        // Keo lai dung image vua push de chung minh registry hoat dong,
        // roi doi ten ve tag ma compose can dung cho buoc DEPLOY.
        sh '''
          set -e
          for s in ${SERVICES}; do
            docker pull "${IMAGE}-${s}:${SHA_SHORT}"
            docker tag  "${IMAGE}-${s}:${SHA_SHORT}" "${COMPOSE_PROJECT}-${s}:latest"
          done
        '''
      }
    }

    // ---------- Buoc 5: DEPLOY ----------
    stage('5. DEPLOY') {
      steps {
        sh '''
          set -e
          # --no-build: dung dung image da pull o buoc PULL, khong build lai.
          docker compose -p ${COMPOSE_PROJECT} up -d --no-build

          echo "=== Cho backend san sang (toi da 180s) ==="
          for i in $(seq 1 60); do
            c=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 \
                "http://host.docker.internal:${DEPLOY_BACKEND_PORT}/api/students" || true)
            if [ "$c" = "200" ]; then
              echo "backend OK sau $((i*3))s"
              break
            fi
            sleep 3
          done

          echo "=== Kiem tra sau deploy ==="
          BACKEND_PORT=${DEPLOY_BACKEND_PORT} \
          FRONTEND_PORT=${DEPLOY_FRONTEND_PORT} \
          COMPOSE_PROJECT=${COMPOSE_PROJECT} \
            sh ci/smoke-test.sh
        '''
      }
    }
  }

  post {
    success {
      echo "DEPLOY THANH CONG - ${IMAGE}:${SHA_SHORT} tai http://localhost:${DEPLOY_FRONTEND_PORT}"
    }
    failure {
      // Van de gi cung de stack dang chay de cham doa, khong xoa ngay.
      echo "BUILD THAT BAI - xem log stage that bai o tren."
    }
    always {
      sh 'docker logout ${REGISTRY} || true'
    }
  }
}
