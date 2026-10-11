// =============================================================================
// Jenkinsfile — BAI 2: BUILD → TEST → PUSH → PULL → DEPLOY
//
// Agent: container Jenkins trong jenkins/docker-compose.yml (Linux, kieu DooD —
// docker CLI dieu khien Docker Desktop cua laptop qua socket mount). Vi theo `sh`,
// KHONG phai powershell nhu pipeline Windows truoc day.
//
// Chu bi 1 lan tren Jenkins (xem README muc CI/CD):
//   1. Tao GitHub PAT quyen write:packages + read:packages
//   2. Tao credential "ghcr-credentials" (Username with password):
//      Username = ten GitHub, Password = PAT (khong phai mat khau GitHub)
//   3. Tao job Pipeline → Pipeline script from SCM → repo GitHub,
//      Branch Specifier */master, Script Path Jenkinsfile
//
// Image: ghcr.io/<user>/studentmanager-<backend|frontend|database>
//   tag: <branch>, <sha12>, va "master" khi o nhánh master
//
// Vi sao chi push linux/amd64 (khong multi-arch nhu huong dan macOS):
//   may nay la x86_64, va anh SQL Server 2022 chi co manifest amd64 —
//   build arm64 se loi "no matching manifest".
// =============================================================================
pipeline {
    agent any

    options {
        disableConcurrentBuilds(abortPrevious: true)
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        GHCR_CREDS = credentials('ghcr-credentials') // → GHCR_CREDS_USR / GHCR_CREDS_PSW
        APP        = 'studentmanager'
        PLATFORM   = 'linux/amd64'
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        // Stage 0 — Chuân be: in ra ten image, kien truc may, kien truc se push
        stage('Chuan bi') {
            steps {
                script {
                    // GHCR bat buoc lowercase — lay ten tai khoan tu credential, khong can doi tay
                    env.IMG_NS   = "ghcr.io/${env.GHCR_CREDS_USR.toLowerCase()}"
                    def raw      = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'master'
                    env.BRANCH   = raw.tokenize('/').last().toLowerCase().replaceAll(/[^a-z0-9._-]/, '-')
                    env.IMG_TAG  = env.BRANCH
                    env.IMG_SHA  = (env.GIT_COMMIT ?: 'nogit').take(12)
                    env.IMG_BASE = "${env.IMG_NS}/${env.APP}"
                }
                sh '''
                    echo "Image     : $IMG_NS/$APP-<backend|frontend|database>:$IMG_TAG"
                    echo "May nay   : $(docker info --format '{{.Architecture}}')"
                    echo "Se push   : $PLATFORM (SQL Server 2022 chi co manifest amd64)"
                    echo "Dung smoke-test: scripts/smoke-test.sh"
                '''
            }
        }

        // Stage 1. BUILD — build anh native, --load vao Docker local de stage TEST dung ngay
        stage('BUILD') {
            steps {
                sh '''
                    set -e
                    for c in backend frontend database; do
                        docker build --platform "$PLATFORM" -t "$IMG_BASE-$c:$IMG_TAG" -t "$IMG_BASE-$c:$IMG_SHA" "$c"
                    done
                '''
            }
        }

        // Stage 2. TEST — smoke test tren anh VUA BUILD (khong build lai, khong pull)
        stage('TEST') {
            steps {
                sh '''
                    set -e
                    echo "=== Chế độ: test image có sẵn -> $IMG_BASE-*:$IMG_TAG ==="
                    export IMAGE_NS="$IMG_NS" IMAGE_TAG="$IMG_TAG"
                    docker compose -p sms-test -f docker-compose.test.yml up -d
                    # goi qua host.docker.internal vi app chay tren Docker Desktop cua host,
                    # container Jenkins khong co localhost cua host
                    BASE_URL="http://host.docker.internal:13000" bash scripts/smoke-test.sh
                '''
            }
            post {
                always {
                    // xoa stack test sau moi lan chay — dung volume rieng nen khong cham du lieu prod
                    sh '''
                        docker compose -p sms-test -f docker-compose.test.yml down -v --remove-orphans || true
                    '''
                }
            }
        }

        // Stage 3. PUSH — build du tag roi day len GHCR; password khong in vao log
        stage('PUSH') {
            steps {
                sh '''
                    set -e
                    printf '%s' "$GHCR_CREDS_PSW" | docker login ghcr.io -u "$GHCR_CREDS_USR" --password-stdin
                    for c in backend frontend database; do
                        docker push "$IMG_BASE-$c:$IMG_TAG"
                        docker push "$IMG_BASE-$c:$IMG_SHA"
                        if [ "$IMG_TAG" = "master" ] || [ "$IMG_TAG" = "main" ]; then
                            docker tag "$IMG_BASE-$c:$IMG_TAG" "$IMG_BASE-$c:latest"
                            docker push "$IMG_BASE-$c:latest"
                        fi
                    done
                    echo "--- Kiem tra image da len registry ---"
                    docker buildx imagetools inspect "$IMG_BASE-backend:$IMG_TAG" --format '{{json .Manifest}}'
                '''
            }
        }

        // Stage 4. PULL — XOA ban local truoc, roi keo lai tu registry.
        // Day la buoc chung minh image tren registry dung duoc — chinh lai khong phai
        // la anh local van chay ngon ma server that kei ve chet.
        stage('PULL') {
            steps {
                sh '''
                    set -e
                    for c in backend frontend database; do
                        docker rmi -f "$IMG_BASE-$c:$IMG_TAG" "$IMG_BASE-$c:$IMG_SHA" "$IMG_BASE-$c:latest" 2>/dev/null || true
                        docker pull "$IMG_BASE-$c:$IMG_TAG"
                    done
                    echo "Kien truc cua anh vua keo ve:"
                    docker image inspect --format '{{.Os}}/{{.Architecture}}  {{.RepoTags}}' "$IMG_BASE-backend:$IMG_TAG"
                '''
            }
        }

        // Stage 5. DEPLOY — chay stack tu image da keo ve (chi pull, khong build)
        stage('DEPLOY') {
            steps {
                sh '''
                    set -e
                    export IMAGE_NS="$IMG_NS" IMAGE_TAG="$IMG_TAG"
                    docker compose -p studentmanager-prod -f docker-compose.prod.yml pull
                    docker compose -p studentmanager-prod -f docker-compose.prod.yml up -d
                    echo "Deploy xong — frontend: http://localhost:3000 (tag=$IMG_TAG)"
                '''
            }
        }

        // Stage 6. Kiểm tra sau deploy — goi lai app qua host.docker.internal
        stage('Kiem tra sau deploy') {
            steps {
                sh '''
                    set -e
                    echo "--- Cho app san sang (toi da 180s) ---"
                    ok=0
                    for i in $(seq 1 60); do
                        if curl -fsS "http://host.docker.internal:3000/api/students" >/dev/null 2>&1; then
                            ok=1; echo "App sẵn sàng sau $((i*3))s"; break
                        fi
                        sleep 3
                    done
                    [ "$ok" = "1" ] || { echo "App khong len duoc sau deploy"; exit 1; }
                    echo "GET / -> $(curl -s -o /dev/null -w '%{http_code}' http://host.docker.internal:3000/)"
                    echo "GET /api/students:"
                    curl -fsS http://host.docker.internal:3000/api/students
                    echo
                '''
            }
        }
    }

    post {
        always {
            // dam bao khong con container test/CI nao con sot lai sau moi lan build
            sh '''
                docker compose -p sms-test -f docker-compose.test.yml down -v --remove-orphans 2>/dev/null || true
                docker logout ghcr.io 2>/dev/null || true
            '''
        }
    }
}
