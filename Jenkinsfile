// =============================================================================
// Jenkinsfile — CI/CD cho Student Manager (Spring Boot + Thymeleaf + SQL Server)
// Agent: Windows (máy local), bắt buộc Docker Desktop đang chạy.
//
// Chuẩn bị 1 lần trên Jenkins:
//   1. Cài plugin: Pipeline, Git (tùy chọn: GitHub Integration)
//   2. Tạo Credential ID "dockerhub-cred" (loại "Username with password"):
//      Username = user Docker Hub, Password = Personal Access Token (PAT) Docker Hub
//   3. Tạo Job "Multibranch Pipeline" trỏ vào repo GitHub (Jenkinsfile nằm ở root):
//      + Behaviours → Add scan trigger → "GitHub hook trigger for GITScm polling"
//        để build tự động mỗi lần push lên GitHub
//   4. Agent Windows cần: Docker Desktop đang chạy, git trong PATH
//      JDK: pipeline tự dùng JDK_FALLBACK bên dưới nếu JAVA_HOME chưa set
//
// Image push lên Docker Hub với tên: <user>/studentmanager-<backend|frontend|database>
//   tag: <branch>, <sha12>, và "latest" khi ở nhánh main/master
// =============================================================================
pipeline {
    agent any

    options {
        disableConcurrentBuilds(abortPrevious: true)
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        DOCKERHUB   = credentials('dockerhub-cred') // → DOCKERHUB_USR / DOCKERHUB_PSW
        IMG_BASE    = "${env.DOCKERHUB_USR}/studentmanager"
        DB_CI_NAME  = 'sms-ci-db'
        DB_CI_PASS  = 'CI_Passw0rd1'    // mật khẩu SQL Server chỉ dùng trong CI (throwaway, không phải prod)
        JDK_FALLBACK = 'C:\\oracleJdk-27' // JDK cài sẵn trên máy dev này — đổi nếu Jenkins ở máy khác
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        // Tạo SQL Server cho test bằng image từ database/ (giống CI GitHub Actions)
        stage('SQL Server cho test') {
            steps {
                powershell '''
                    docker build -q -t studentmanager-db:ci database | Out-Null
                    docker rm -f $env:DB_CI_NAME 2>$null | Out-Null
                    docker run -d --name $env:DB_CI_NAME -p 1433:1433 `
                        -e ACCEPT_EULA=Y -e MSSQL_PID=Developer `
                        -e MSSQL_SA_PASSWORD=$env:DB_CI_PASS `
                        studentmanager-db:ci

                    # Cho SQL Server khoi dong that su (doi log "ready"), toi da ~5 phut.
                    # NOTE: chi check TCP khong du — Docker Desktop proxy chap nhan ket noi
                    # ngay khi container chua khoi dong xong (false positive).
                    $ok = $false
                    for ($i = 0; $i -lt 150; $i++) {
                        $logs = (docker logs $env:DB_CI_NAME 2>&1 | Out-String)
                        if ($logs -match 'SQL Server is now ready for client connections') { $ok = $true; break }
                        $running = (docker inspect -f '{{.State.Running}}' $env:DB_CI_NAME 2>$null | Out-String).Trim()
                        if ($running -ne 'true') { Write-Output 'Container da dung chay som' ; break }
                        Start-Sleep -Seconds 2
                    }
                    if (-not $ok) {
                        Write-Output '=== trang thai container ==='
                        docker ps -a --filter name=$env:DB_CI_NAME
                        Write-Output '=== logs container ==='
                        docker logs $env:DB_CI_NAME 2>&1 | Select-Object -Last 40
                        throw 'SQL Server khong ready duoc'
                    }
                    # Cho port 1433 mo that su (toi da 60s)
                    for ($i = 0; $i -lt 30; $i++) {
                        try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1', 1433); $t.Close(); break } catch { Start-Sleep -Seconds 2 }
                    }
                    Write-Output 'SQL Server da san sang'
                '''
            }
        }

        stage('Backend test (Maven)') {
            steps {
                powershell '''
                    # Dam bao CI DB con chay truoc khi test (tru hang cho khong can thiet)
                    $st = (docker inspect -f '{{.State.Status}}' $env:DB_CI_NAME 2>$null | Out-String).Trim()
                    Write-Output "CI DB trang thai truoc test: $st"
                    if ($st -ne 'running') {
                        docker ps -a --filter name=$env:DB_CI_NAME
                        docker logs $env:DB_CI_NAME 2>&1 | Select-Object -Last 40
                        throw 'CI DB khong con chay truoc khi test'
                    }
                    if (-not $env:JAVA_HOME) { $env:JAVA_HOME = $env:JDK_FALLBACK }
                    $env:Path = "$env:JAVA_HOME\\bin;" + $env:Path
                    java -version
                    $env:SPRING_DATASOURCE_URL = 'jdbc:sqlserver://localhost:1433;databaseName=school;trustServerCertificate=true'
                    $env:SPRING_DATASOURCE_USERNAME = 'sa'
                    $env:SPRING_DATASOURCE_PASSWORD = $env:DB_CI_PASS
                    Set-Location backend
                    .\\mvnw.cmd -B test
                '''
            }
        }

        stage('Docker login') {
            steps {
                // Mat khau khong in ra console — pipe truc tiep vao docker login.
                // Dung bash printf "%s" (Git for Windows): PowerShell 5.1 pipe them CRLF,
                // docker chi trim "\n" con lai "\r" → password sai → login that bai.
                powershell '''& 'C:\Program Files\Git\bin\bash.exe' -c 'printf "%s" "$DOCKERHUB_PSW" | docker login -u "$DOCKERHUB_USR" --password-stdin' '''
            }
        }

        // Build 3 image (backend/frontend/database) + push: <branch>, <sha12>, latest (nhanh mac dinh)
        stage('Build & Push') {
            matrix {
                axes {
                    axis {
                        name 'APP_IMAGE'
                        values 'backend', 'frontend', 'database'
                    }
                }
                stages {
                    stage('Build & Push image') {
                        steps {
                            script {
                                def branch    = (env.BRANCH_NAME ?: 'local').toLowerCase().replaceAll(/[^a-z0-9._-]/, '-')
                                def sha       = (env.GIT_COMMIT ?: 'nogit').take(12)
                                def base      = "${env.IMG_BASE}-${env.APP_IMAGE}".toLowerCase()
                                def isDefault = ['main', 'master'].contains(branch)
                                def extra     = isDefault ? "-t ${base}:latest" : ''
                                powershell "docker build -t ${base}:${branch} -t ${base}:${sha} ${extra} ${env.APP_IMAGE}"
                                powershell "docker push ${base}:${branch}"
                                powershell "docker push ${base}:${sha}"
                                if (isDefault) { powershell "docker push ${base}:latest" }
                            }
                        }
                    }
                }
            }
        }

        // Deploy tu dong moi nhanh (tag = ten nhanh; main/master dung tag latest)
        stage('Deploy') {
            steps {
                powershell '''
                    # Tra lai port 1433 cho stack deploy (container CI dung chung port)
                    docker rm -f $env:DB_CI_NAME 2>$null | Out-Null

                    $env:IMAGE_NS = $env:DOCKERHUB_USR
                    if ($env:BRANCH_NAME -and $env:BRANCH_NAME -notin @('main', 'master')) {
                        $env:IMAGE_TAG = $env:BRANCH_NAME.ToLower()
                    } else {
                        $env:IMAGE_TAG = 'latest'
                    }
                    docker compose -f docker-compose.deploy.yml pull
                    docker compose -f docker-compose.deploy.yml up -d
                    Write-Output "Deploy xong — frontend: http://localhost:3000 (tag=$env:IMAGE_TAG)"
                '''
            }
        }
    }

    post {
        always {
            // Log truoc, xoa sau — post "always" chay truoc "failure" nen neu tach
            // thanh 2 block se mat log khi phan tich loi
            powershell '''
                Write-Output '=== logs CI DB (truoc khi xoa) ==='
                docker logs $env:DB_CI_NAME 2>&1 | Select-Object -Last 60
                docker rm -f $env:DB_CI_NAME 2>$null | Out-Null
                exit 0
            '''
        }
    }
}
