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
        timestamps()
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

                    # Cho SQL Server mở port 1433 (toi da ~3 phut)
                    $ok = $false
                    for ($i = 0; $i -lt 90; $i++) {
                        try {
                            $t = New-Object Net.Sockets.TcpClient
                            $t.Connect('127.0.0.1', 1433)
                            $t.Close()
                            $ok = $true
                            break
                        } catch { Start-Sleep -Seconds 2 }
                    }
                    if (-not $ok) { throw 'SQL Server khong mo duoc port 1433' }
                    Start-Sleep -Seconds 20
                    Write-Output 'SQL Server da san sang'
                '''
            }
        }

        stage('Backend test (Maven)') {
            steps {
                powershell '''
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
                // Mat khau khong in ra console — pipe truc tiep vao docker login
                powershell 'Write-Output $env:DOCKERHUB_PSW | docker login -u $env:DOCKERHUB_USR --password-stdin'
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
            // Don container CI (khong anh huong toi stack deploy dang chay)
            powershell 'docker rm -f $env:DB_CI_NAME 2>$null | Out-Null; exit 0'
        }
        failure {
            powershell 'docker logs $env:DB_CI_NAME 2>&1 | Select-Object -Last 100; exit 0'
        }
    }
}
