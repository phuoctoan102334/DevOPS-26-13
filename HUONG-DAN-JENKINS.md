# HƯỚNG DẪN JENKINS CHO DỰ ÁN STUDENT MANAGEMENT SYSTEM

> Mục tiêu: dựng Jenkins ngay trên máy của bạn, chạy đủ 5 bước
> **BUILD → TEST → PUSH → PULL → DEPLOY**, kết thúc bằng ứng dụng chạy thật ở
> http://localhost:3000 (frontend) + http://localhost:8080/api/students (backend)
> từ image kéo về từ registry.

Đây là bản viết cho dự án này, dựa trên bài mẫu trong thư mục `baimau/`.
Khác biệt chính: dự án có **3 service** (backend Spring Boot, frontend nginx,
database SQL Server) nên pipeline build/push/pull **3 image** thay vì 1, và
smoke test thử luôn **CRUD API** thay vì chỉ health check.

---

## 1. Các file đã có

| File | Vai trò |
| --- | --- |
| `Jenkinsfile` | Pipeline 6 stage: BUILD → TEST → PUSH → PULL → DEPLOY → kiểm tra |
| `jenkins/Dockerfile` | Image Jenkins + docker CLI + Compose v2 + plugin |
| `jenkins/docker-compose.yml` | Dựng Jenkins (cổng **8090**, socket Docker của máy) |
| `docker-compose.prod.yml` | Override `build:` → `image:` để deploy **không build lại** |
| `scripts/smoke-test.sh` | Smoke test 10 phép thử: trang chủ, proxy, CRUD API |

```
machine (Windows / Docker Desktop WSL2)
│
├── container jenkins (:8090) ── docker CLI ──┐
│                                             │ qua /var/run/docker.sock
│                                             ▼
│                                    Docker Desktop (daemon thật)
│                                    ├─ student-mgmt-prod-frontend → :3000
│                                    ├─ student-mgmt-prod-backend  → :8080
│                                    └─ student-mgmt-prod-database → :1433
└── host.docker.internal (Jenkins stage 6 gọi kiểm tra)
                                            ▲
                                            │ push / pull
                                     ghcr.io/phuoctoan102334/student-management-*
```

Jenkins **không** chạy Docker riêng bên trong — chỉ có `docker` CLI điều khiển
Docker Desktop qua socket được mount vào (kiểu **DooD** — Docker outside of Docker).

---

## 2. Chuẩn bị

### 2.1. Tạo Personal Access Token để push lên GHCR

1. GitHub → Settings → Developer settings → **Personal access tokens** → **Tokens (classic)**
2. **Generate new token (classic)**
3. Note: `jenkins-ghcr`, Expiration: 90 days
4. Tick đúng 2 quyền: `write:packages`, `read:packages`
5. **Generate token** → **copy ngay** (chỉ hiện một lần)

### 2.2. Tên tài khoản trong Jenkinsfile

Jenkinsfile đã set sẵn theo repo của bạn:

```groovy
IMAGE_NAME = 'phuoctoan102334/student-management'   // viết thường toàn bộ
```

Nếu bạn **fork** dự án, đổi thành `<tài khoản GitHub của bạn>/student-management`.
GHCR **không nhận chữ hoa** — sai là báo `invalid reference format`.

---

## 3. Dựng Jenkins

```powershell
cd jenkins
docker compose up -d --build
```

Lần đầu mất ~3–5 phút (tải Jenkins + cài Docker CLI + plugin).
Mở **http://localhost:8090** — vào thẳng giao diện, không hỏi mật khẩu.

> Cổng **8090** chứ không phải 8080: 8080 đã dành cho backend của app khi deploy.

Kiểm tra Jenkins gọi được Docker:

```powershell
docker exec jenkins docker version --format '{{.Server.Version}} / {{.Server.Arch}}'
```

Phải ra kiểu `28.x.x / amd64`. Nếu báo `Cannot connect to the Docker daemon` → xem mục 8.

---

## 4. Tạo credential cho GHCR

Jenkins → **Manage Jenkins** → **Credentials** → **System** →
**Global credentials** → **Add Credentials**

| Trường | Giá trị |
| --- | --- |
| Kind | **Username with password** |
| Username | `phuoctoan102334` |
| Password | **token** vừa tạo ở 2.1 (không phải mật khẩu GitHub) |
| ID | `ghcr-credentials` ← **phải đúng chuỗi này** |

---

## 5. Tạo pipeline job

Jenkins → **New Item** → tên `student-cicd` → chọn **Pipeline** → OK.

Trong phần **Pipeline**:

| Trường | Giá trị |
| --- | --- |
| Definition | **Pipeline script from SCM** |
| SCM | **Git** |
| Repository URL | `https://github.com/phuoctoan102334/Student-Management-System.git` |
| Branch Specifier | `*/main` |
| Script Path | `Jenkinsfile` |

**Save**.

> Repo private thì thêm credential Git riêng. Laptop không có IP public nên
> không dùng webhook: Jenkinsfile đã khai `pollSCM('H/2 * * * *')` — tự kiểm
> commit mới 2 phút/lần.

---

## 6. Chạy và đọc kết quả

Bấm **Build Now**, theo dõi **Console Output**.

| Stage | Bạn sẽ thấy | Ý nghĩa |
| --- | --- | --- |
| **Chuẩn bị** | `Máy này : linux/amd64`, `Sẽ push : linux/amd64,linux/arm64` | Login GHCR + cài QEMU + tạo builder buildx |
| **1. BUILD** | `[backend] có cache...`, 3 image `student-management-*:a1b2c3d` | Build bản **native** (nhanh, không giả lập) + `--load` vào Docker local |
| **2. TEST** | `Chế độ: test image có sẵn`, `PASS  Frontend tra 200`, ... `=== Kết quả: 10 đạt, 0 hong ===` | Smoke test stack đầy đủ **không build lại** |
| **3. PUSH** | In ra `linux/amd64` + `linux/arm64` | Build đa kiến trúc, đẩy 3 image lên GHCR |
| **4. PULL** | `docker rmi` → `docker pull`, `Kiến trúc backend vừa kéo về: linux/amd64` | Ép tải thật từ registry — đúng việc server thật sẽ làm |
| **5. DEPLOY** | `Container student-mgmt-prod-backend  Started` | `compose up -d` bằng **image vừa pull**, giữ volume `sqldata` |
| **6. Kiểm tra** | `App sẵn sàng sau ~3x3s`, `[{"id":1,...}]`, `HTTP 200` | Gọi ra host qua `host.docker.internal` |

Mở **http://localhost:3000** — app chạy từ image đã đi trọn vòng
build → test → push → pull → deploy. Dữ liệu SQL Server nằm trong volume
`sqldata` nên **sống sót qua các lần deploy**.

### Smoke test gồm 10 phép thử

1. Frontend trả 200 ở `/`
2. Trang chủ là HTML thật
3. Backend `/api/students` trả JSON array
4. Nginx proxy `/api/` → backend hoạt động
5. `POST /api/students` tạo được sinh viên
6. `GET /api/students/9001` đúng dữ liệu
7. Tìm kiếm theo tên hoạt động
8. `POST update/{id}` hoạt động
9. `POST delete/{id}` hoạt động
10. Sau xoá, `GET` trả về `null`

Script tự dùng cổng riêng (3999 / 55999 / 15333) và **tự dọn stack + volume**
khi thoát nên không đụng stack deploy thật, lần chạy sau luôn sạch.

---

## 7. Rollback

Lấy sha của build cũ trong **Build History** (hoặc `docker images`), rồi:

```powershell
$env:BACKEND_IMAGE  = "ghcr.io/phuoctoan102334/student-management-backend:<sha_cũ>"
$env:FRONTEND_IMAGE = "ghcr.io/phuoctoan102334/student-management-frontend:<sha_cũ>"
$env:DATABASE_IMAGE = "ghcr.io/phuoctoan102334/student-management-database:<sha_cũ>"
$env:FRONTEND_PORT = "3000"; $env:BACKEND_PORT = "8080"; $env:DB_PORT = "1433"
$env:MSSQL_SA_PASSWORD = "SA_Passw0rd1"

docker compose -p student-mgmt-prod -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 8. Lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
| --- | --- | --- |
| `Cannot connect to the Docker daemon` | Chưa mount socket, hoặc sai group | Kiểm tra `jenkins/docker-compose.yml` có `/var/run/docker.sock:/var/run/docker.sock` và `group_add: ["0"]`. Trên **Linux** đổi `"0"` thành kết quả `stat -c '%g' /var/run/docker.sock` |
| `docker: not found` trong pipeline | Dùng image `jenkins/jenkins` gốc | Phải `docker compose up -d --build` để dùng `jenkins/Dockerfile` đã cài docker CLI |
| `denied` khi push | Token thiếu quyền / sai credential ID | Token phải có `write:packages`. Credential ID phải đúng `ghcr-credentials` |
| `invalid reference format` | `IMAGE_NAME` có chữ HOA | Viết thường toàn bộ |
| `services.database.build must be null` hoặc báo `!reset` lạ | Docker Compose cũ (< 2.24) | Nâng Docker Desktop, kiểm tra `docker compose version` |
| Stage 6 timeout (270s) | SQL Server khởi động chậm hoặc Jenkins không gọi ra host | `docker exec jenkins getent hosts host.docker.internal` phải ra IP. Xem `docker compose -p student-mgmt-prod logs database` |
| Port 3000/8080/1433 bị chiếm | Stack cũ còn dừng dở, hoặc app khác (IIS, SQL Server thật...) | Stack cũ: `docker compose -p student-mgmt-prod -f docker-compose.yml -f docker-compose.prod.yml down`. App khác thật sự cần → đổi port trong `docker-compose.prod.yml` và Jenkinsfile |
| Port 8090 bị chiếm lúc dựng Jenkins | Tiến trình khác giữ cổng | `docker compose -p ... logs jenkins` / đổi `"8090:8080"` trong `jenkins/docker-compose.yml` |
| Build arm64 rất lâu ở stage PUSH | QEMU giả lập, Maven + JVM chạy qua giả lập chậm | Bình thường lần đầu ~2–5 phút (đã tăng timeout lên 45'). Lần sau có cache nhanh hơn nhiều. Vẫn thấy chậm? Đổi `PLATFORMS = 'linux/amd64'` trong Jenkinsfile |
| `no space left on device` | Image cũ chất đống | `docker image prune -a --filter until=168h`, hoặc `docker system prune -a --volumes` (xoá sạch, cẩn thận) |
| Smoke test báo `Không gọi được host.docker.internal` | Chạy tay trên Linux không có tên này | Thêm `extra_hosts: ["host.docker.internal:host-gateway"]` vào docker-compose của app, hoặc chạy với `SMOKE_HOST=localhost` trên Windows/Mac |
| Lệnh `.sh` báo `\r: command not found` khi chạy tay trên Windows | File CRLF | Đã khai `*.sh text eol=lf` trong `.gitattributes`; nếu vẫn bị: `bash scripts/smoke-test.sh` sau khi checkout lại |
| `ERROR: exporting cache to registry` ở lần chạy đầu | Chưa có tag `:buildcache` trên GHCR | Bỏ qua được, `ignore-error=true` giữ build thành công. Lần chạy sau hết báo |

---

## 9. Dọn dẹp sau khi học xong

```powershell
# Dừng app deploy
docker compose -p student-mgmt-prod -f docker-compose.yml -f docker-compose.prod.yml down

# Dừng Jenkins (giữ dữ liệu job)
cd jenkins; docker compose down

# Xoá luôn cả dữ liệu Jenkins
docker compose down -v
```

---

## 10. Muốn thêm unit test Java (tuỳ chọn)

Pipeline hiện gate chất lượng bằng smoke test. Muốn chạy thêm `mvn test`
trước khi build image, thêm stage này ngay sau `Chuẩn bị` — không cần mount
workspace, chỉ cần image Maven:

```groovy
stage('0. Unit test') {
  steps {
    dir('backend') {
      sh '''
        docker run --rm -v "$PWD":/app -v m2cache:/root/.m2 -w /app \
          maven:3.9-eclipse-temurin-21 mvn -B test
      '''
    }
  }
}
```

> Lưu ý DooD: `-v "$PWD"` chỉ hoạt động nếu đường dẫn workspace của Jenkins
> TRÙNG đường dẫn trên host. Nếu báo `no such file or directory`, bỏ stage này
> hoặc chạy test ngay trong `docker build --target test` bằng cách tách một
> stage Maven riêng trong `backend/Dockerfile`.
