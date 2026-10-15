// ===================================================================
// STUDENT MANAGEMENT SYSTEM — Jenkins: BUILD -> TEST -> PUSH -> PULL -> DEPLOY
// ===================================================================
// Dựng theo baimau/huong-dan-jenkins.md, viết lại cho dự án 3 service:
//   backend  (Spring Boot 3 + Java 21 + Maven)
//   frontend (nginx tĩnh + proxy /api/ -> backend)
//   database (SQL Server 2022 + script khởi tạo school.students)
//
// Ba nguyên tắc (giữ nguyên của bài mẫu):
//
// 1) BUILD MỘT LẦN cho mỗi kiến trúc, KHÔNG build lại khi deploy.
//    Stage DEPLOY chạy bằng image đã pull từ registry (docker-compose.prod.yml
//    dùng "image:", không "build:").
//
// 2) IMAGE ĐA KIẾN TRÚC (amd64 + arm64) — chạy được trên mọi máy.
//
// 3) TEST TRÊN KIẾN TRÚC MÁY MÌNH: build bản native trước, smoke test
//    toàn bộ stack (DB + backend + frontend + CRUD API), đạt rồi mới
//    build đa kiến trúc để push.
// ===================================================================

pipeline {
  agent any

  environment {
    REGISTRY   = 'ghcr.io'
    // Tài khoản GHCR phải là CHỦ token trong credential (token o_ thuoc DanhTaiSeck)
    IMAGE_NAME = 'danhtaiceck/student-management'
    IMAGE      = "${REGISTRY}/${IMAGE_NAME}"

    // Credential kiểu "Username with password":
    //   user     = tên GitHub
    //   password = Personal Access Token có quyền write:packages
    GHCR_CREDS = credentials('ghcr-credentials')

    // Các kiến trúc sẽ push lên registry
    PLATFORMS = 'linux/amd64,linux/arm64'

    // Cổng stack deploy thật (khác cổng smoke test 3999/55999/15333 để không đụng nhau)
    DEPLOY_FRONTEND_PORT = '3000'
    DEPLOY_BACKEND_PORT  = '8080'
    DEPLOY_DB_PORT       = '1433'
    DEPLOY_PROJECT       = 'student-mgmt-prod'

    // Password SQL Server cho cả smoke test lẫn deploy
    SA_PASSWORD = 'SA_Passw0rd1'
  }

  options {
    timestamps()
    // 45 phút: build arm64 cho Maven dưới QEMU giả lập khá lâu lần đầu
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))   // giữ 10 bản gần nhất để rollback
  }

  triggers {
    // Laptop không có IP public nên GitHub không gọi webhook vào được
    // -> Jenkins chủ động hỏi 2 phút/lần xem có commit mới không.
    pollSCM('H/2 * * * *')
  }

  stages {

    // ---------- Chuẩn bị: tag + máy build đa kiến trúc ----------
    stage('Chuẩn bị') {
      steps {
        script {
          env.SHA_SHORT = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
          // Kiến trúc của chính máy Jenkins đang chạy (amd64 trên PC Windows/Linux)
          env.NATIVE_ARCH = sh(
            script: "docker version --format '{{.Server.Arch}}'",
            returnStdout: true
          ).trim()
        }

        echo "Images    : ${IMAGE}-{backend,frontend,database}:${env.SHA_SHORT}"
        echo "Máy này   : linux/${env.NATIVE_ARCH}"
        echo "Sẽ push   : ${PLATFORMS}"

        // Đăng nhập NGAY từ đầu vì stage BUILD đã cần ghi cache lên registry.
        // --password-stdin: token không lộ trong log hay danh sách tiến trình.
        sh '''
          echo "$GHCR_CREDS_PSW" | docker login ${REGISTRY} -u "$GHCR_CREDS_USR" --password-stdin
        '''

        // QEMU: cho phép build kiến trúc khác với máy hiện tại (giả lập).
        // Buildx builder: bắt buộc để build nhiều kiến trúc cùng lúc.
        sh '''
          docker run --privileged --rm tonistiigi/binfmt --install all || true
          docker buildx create --name multiarch --driver docker-container --use 2>/dev/null \
            || docker buildx use multiarch
          docker buildx inspect --bootstrap
        '''
      }
    }

    // ---------- BƯỚC 1: BUILD ----------
    stage('1. BUILD') {
      steps {
        script {
          def services = ['backend', 'frontend', 'database']
          for (def svc : services) {
            echo "=== Build bản native (linux/${env.NATIVE_ARCH}) cho ${svc} ==="
            // --load nạp image vào Docker local để stage TEST dùng ngay.
            // Cache đẩy lên registry (tag :<svc>-buildcache) để stage PUSH dùng lại.
            // Lần chạy đầu chưa có tag buildcache trên registry:
            //   - cache-to  : ignore-error=true lo được
            //   - cache-from: PHẢI kiểm tra tag tồn tại trước, nếu không build hỏng
            sh """
              CACHE_TAG=${IMAGE}-${svc}:buildcache
              if docker buildx imagetools inspect \$CACHE_TAG >/dev/null 2>&1; then
                CACHE_FROM="--cache-from type=registry,ref=\$CACHE_TAG"
                echo "[${svc}] có cache trên registry -> dùng lại"
              else
                CACHE_FROM=""
                echo "[${svc}] chưa có cache (lần đầu) -> build từ đầu"
              fi

              docker buildx build \\
                --platform linux/${env.NATIVE_ARCH} \\
                --tag ${IMAGE}-${svc}:${env.SHA_SHORT} \\
                \$CACHE_FROM \\
                --cache-to type=registry,ref=\$CACHE_TAG,mode=max,ignore-error=true \\
                --load \\
                ./${svc}
            """
          }
        }
        sh "docker images --filter=reference='${IMAGE}-*' --format 'table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}'"
      }
    }

    // ---------- BƯỚC 2: TEST ----------
    stage('2. TEST') {
      steps {
        echo "=== Smoke test stack đầy đủ từ 3 image vừa build ==="
        // SMOKE_IMAGE_BASE + SMOKE_IMAGE_TAG khiến script dùng
        // docker-compose.prod.yml -> chạy đúng image này, KHÔNG build lại.
        // SMOKE_PROJECT khác nhau mỗi build -> dọn sạch volume DB mỗi lần chạy.
        sh """
          chmod +x scripts/smoke-test.sh
          SMOKE_IMAGE_BASE=${IMAGE} \\
          SMOKE_IMAGE_TAG=${env.SHA_SHORT} \\
          SMOKE_PROJECT=student-smoke-${BUILD_NUMBER} \\
          ./scripts/smoke-test.sh
        """
      }
    }

    // ---------- BƯỚC 3: PUSH ----------
    stage('3. PUSH') {
      steps {
        script {
          def services = ['backend', 'frontend', 'database']
          for (def svc : services) {
            echo "=== Build đa kiến trúc + đẩy ${svc} lên ${REGISTRY} ==="
            // buildx đẩy thẳng manifest list (1 tag chứa nhiều kiến trúc).
            // Bản native lấy lại từ cache (đúng layer vừa test), chỉ kiến trúc
            // còn lại phải build thêm (arm64 chạy qua QEMU, lần đầu ~2-5 phút).
            sh """
              CACHE_TAG=${IMAGE}-${svc}:buildcache
              if docker buildx imagetools inspect \$CACHE_TAG >/dev/null 2>&1; then
                CACHE_FROM="--cache-from type=registry,ref=\$CACHE_TAG"
              else
                CACHE_FROM=""
              fi

              docker buildx build \\
                --platform ${PLATFORMS} \\
                --tag ${IMAGE}-${svc}:${env.SHA_SHORT} \\
                --tag ${IMAGE}-${svc}:latest \\
                \$CACHE_FROM \\
                --cache-to type=registry,ref=\$CACHE_TAG,mode=max,ignore-error=true \\
                --push \\
                ./${svc}
            """
          }
        }

        echo "=== Xác nhận image có đủ các kiến trúc ==="
        sh """
          docker buildx imagetools inspect ${IMAGE}-backend:${env.SHA_SHORT} \\
            --format '{{range .Manifest.Manifests}}{{.Platform.OS}}/{{.Platform.Architecture}}{{"\\n"}}{{end}}'
        """
      }
    }

    // ---------- BƯỚC 4: PULL ----------
    stage('4. PULL') {
      steps {
        echo "=== Kéo 3 image từ registry về ==="
        // Xoá bản local trước rồi mới pull: ép Docker tải thật từ registry.
        // Nếu còn bản local, lệnh pull sẽ bỏ qua và ta không kiểm chứng được gì.
        sh """
          for svc in backend frontend database; do
            docker rmi ${IMAGE}-\$svc:${env.SHA_SHORT} 2>/dev/null || true
            docker pull ${IMAGE}-\$svc:${env.SHA_SHORT}
          done
          echo "Kiến trúc backend vừa kéo về:"
          docker image inspect ${IMAGE}-backend:${env.SHA_SHORT} --format '{{.Os}}/{{.Architecture}}'
        """
      }
    }

    // ---------- BƯỚC 5: DEPLOY ----------
    stage('5. DEPLOY') {
      steps {
        echo "=== Deploy lên laptop: frontend :${DEPLOY_FRONTEND_PORT}, backend :${DEPLOY_BACKEND_PORT}, db :${DEPLOY_DB_PORT} ==="
        // docker-compose.prod.yml dùng "image:" nên compose KHÔNG build lại,
        // chạy đúng image vừa kéo từ registry về.
        // KHÔNG dùng "down -v": giữ volume sqldata để dữ liệu sống qua các lần deploy.
        withEnv([
          "BACKEND_IMAGE=${IMAGE}-backend:${env.SHA_SHORT}",
          "FRONTEND_IMAGE=${IMAGE}-frontend:${env.SHA_SHORT}",
          "DATABASE_IMAGE=${IMAGE}-database:${env.SHA_SHORT}",
          "FRONTEND_PORT=${DEPLOY_FRONTEND_PORT}",
          "BACKEND_PORT=${DEPLOY_BACKEND_PORT}",
          "DB_PORT=${DEPLOY_DB_PORT}",
          "MSSQL_SA_PASSWORD=${SA_PASSWORD}"
        ]) {
          sh """
            docker compose -p ${DEPLOY_PROJECT} \\
              -f docker-compose.yml -f docker-compose.prod.yml \\
              up -d --remove-orphans
          """
        }
      }
    }

    // ---------- BƯỚC 6: Kiểm tra sau deploy ----------
    stage('6. Kiểm tra sau deploy') {
      steps {
        echo "=== Xác nhận app chạy thật từ image đã đi trọn vòng ==="
        // Jenkins ở trong container, gọi ra host qua host.docker.internal
        // (đã khai extra_hosts trong jenkins/docker-compose.yml).
        // SQL Server khởi động chậm ~40-60s nên chờ tối đa 4.5 phút.
        sh """
          FE=http://host.docker.internal:${DEPLOY_FRONTEND_PORT}
          BE=http://host.docker.internal:${DEPLOY_BACKEND_PORT}

          READY=0
          for i in \$(seq 1 90); do
            if curl -sf \$BE/api/students >/dev/null 2>&1; then
              READY=1
              echo "App sẵn sàng sau ~\$((i * 3))s"
              break
            fi
            sleep 3
          done
          if [ \$READY -ne 1 ]; then
            echo "TIMEOUT - app không phản hồi sau 270s"
            docker compose -p ${DEPLOY_PROJECT} logs backend | tail -50
            exit 1
          fi

          echo -n "Backend  /api/students : "
          curl -s \$BE/api/students | head -c 300; echo ""
          echo -n "Frontend /              : HTTP "
          curl -s -o /dev/null -w '%{http_code}' \$FE/; echo ""
          echo -n "Qua proxy /api/students : "
          curl -s \$FE/api/students | head -c 300; echo ""
        """
      }
    }
  }

  post {
    success {
      echo """
      =====================================================
      THÀNH CÔNG
        Images : ${IMAGE}-{backend,frontend,database}:${env.SHA_SHORT}
        Push   : ${PLATFORMS}
        App    : http://localhost:${DEPLOY_FRONTEND_PORT}
                 http://localhost:${DEPLOY_BACKEND_PORT}/api/students

      Rollback về bản trước (thay <sha_cũ> bằng sha của build cũ):
        BACKEND_IMAGE=${IMAGE}-backend:<sha_cũ> \\
        FRONTEND_IMAGE=${IMAGE}-frontend:<sha_cũ> \\
        DATABASE_IMAGE=${IMAGE}-database:<sha_cũ> \\
        FRONTEND_PORT=${DEPLOY_FRONTEND_PORT} BACKEND_PORT=${DEPLOY_BACKEND_PORT} DB_PORT=${DEPLOY_DB_PORT} \\
        MSSQL_SA_PASSWORD=${SA_PASSWORD} \\
        docker compose -p ${DEPLOY_PROJECT} \\
          -f docker-compose.yml -f docker-compose.prod.yml up -d
      =====================================================
      """
    }
    failure {
      echo "THẤT BẠI - stack đang chạy KHÔNG bị đụng tới (deploy chỉ chạy sau khi test đạt)."
    }
    always {
      sh 'docker logout ${REGISTRY} || true'
      // Dọn image cũ hơn 7 ngày để laptop không đầy ổ
      sh 'docker image prune -f --filter "until=168h" || true'
    }
  }
}
