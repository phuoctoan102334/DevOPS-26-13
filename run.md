# RUN.MD — Bảng cổng & cách chạy từng kịch bản (Student Manager)

Áp dụng cho máy này (Windows + Docker Desktop, x86_64/amd64). Repo: `https://github.com/phuoctoan102334/DevOPS-26-13.git`, nhánh mặc định **`master`**.

Có **3 stack app** + **2 Jenkins**, mỗi thứ một bộ cổng để có thể chạy song song mà không đè nhau:

| Stack / dịch vụ | File | Dùng khi |
|---|---|---|
| App dev (build từ source) | `docker-compose.yml` | Bạn code local, `docker compose up -d` |
| App test | `docker-compose.test.yml` | Stage **TEST** của pipeline (image local vừa build) |
| App prod (pull từ registry) | `docker-compose.prod.yml` | Stage **DEPLOY** của pipeline / deploy tay |
| Jenkins container (Bài 2) | `jenkins/docker-compose.yml` | Chạy pipeline BUILD→TEST→PUSH→PULL→DEPLOY |
| Jenkins Windows (cũ) | service Windows | Pipeline Docker Hub cũ — **đã tắt job** `student-manager` |

---

## 1. Bảng cổng đầy đủ

### 1.1. App (dùng chung cho dev / test / prod)

| Cổng trên máy (host) | Cổng trong container | Dịch vụ | Mở bằng |
|---|---|---|---|
| **3000** | 80 (nginx) | Frontend — bảng sinh viên | http://localhost:3000 |
| **8080** | 8080 (Spring Boot) | Backend REST API | http://localhost:8080/api/students |
| **1433** | 1433 (SQL Server 2022) | Database `school` | client SQL (DBeaver/SSMS…) |

- Browser chỉ cần **3000**: nginx tự proxy `/api/` → `backend:8080` (xem `frontend/nginx.conf`).
- Gọi thẳng API: **8080**. Muốn test API không cần frontend: `curl http://localhost:8080/api/students`.

### 1.2. Stack TEST (riêng, để không đè cổng dev/prod đang chạy)

| Cổng host | Cổng container | Dịch vụ | Đổi được bằng biến |
|---|---|---|---|
| **13000** | 80 | Frontend (test) | `TEST_WEB_PORT` |
| **18080** | 8080 | Backend (test) | `TEST_API_PORT` |
| **11433** | 1433 | Database (test) | `TEST_DB_PORT` |

### 1.3. Jenkins

| Cổng | Dịch vụ | Ghi chú |
|---|---|---|
| **8090** | Jenkins **container** (UI) | http://localhost:8090 — vào thẳng, không hỏi mật khẩu |
| **50000** | Jenkins container agent (JNLP) | Dự phòng, pipeline hiện dùng `agent any` trên chính Jenkins |
| **8081** | Jenkins **Windows service** (cũ) | https://localhost:8081 — có xác thực, cần tài khoản Jenkins |

> **Vì sao Jenkins là 8090 chứ không phải 8080:** backend app giữ cổng 8080. Nếu Jenkins chiếm 8080 thì stage DEPLOY sẽ dừng với lỗi `port is already allocated` (mục 4.1 trong hướng dẫn gốc cũng khuyên đổi 8090 khi 8080 bị chiếm).

### 1.4. Cổng bên trong (không mở ra ngoài)

| Đường đi | Dùng khi nào |
|---|---|
| `backend` → `database:1433` | JDBC `jdbc:sqlserver://database:1433;databaseName=school` — đi trong network Docker |
| `frontend` → `backend:8080` | nginx proxy `/api/` |
| Container Jenkins → `host.docker.internal:3000/13000` | Pipeline gọi app **từ trong container** Jenkins (vì container không có `localhost` của máy host) |

---

## 2. Cách chạy — Kịch bản A: dev local (không cần Jenkins)

### A1. Chạy hết bằng Docker (khuyên dùng)

```powershell
cd D:\Devops\DevOPS-26-13
docker compose up -d --build     # lần đầu build 3 image, ~3–5 phút
```

- Mở http://localhost:3000 → bảng sinh viên tự tải.
- Kiểm tra: `curl http://localhost:8080/api/students`
- Trạng thái: `docker compose ps`
- Dừng: `docker compose down` (giữ data) / `docker compose down -v` (**mất** data, xóa cả database)

Đổi mật khẩu DB trước khi up (mặc định trong compose chỉ dành cho lab):

```powershell
$env:MSSQL_SA_PASSWORD = "MatKhauCuaBan"
docker compose up -d
```

### A2. Chạy không Docker (chỉ backend + frontend)

- Database: vẫn cần SQL Server đang chạy ở `localhost:1433` (chạy qua Docker ở trên hoặc cài sẵn).
- Backend: `cd backend` → `.\mvnw.cmd spring-boot:run` → http://localhost:8080
- Frontend: mở `frontend/index.html` bằng Live Server → gọi API qua CORS (`WebConfig.java` cho phép `*`)

Lưu ý: `mvn test` sẽ fail `Unable to determine Dialect` nếu SQL Server chưa chạy — lỗi môi trường, không phải lỗi code.

---

## 3. Cách chạy — Kịch bản B: pipeline CI/CD (Bài 2)

Luồng: `Checkout → Chuan bi → BUILD → TEST → PUSH → PULL → DEPLOY → Kiem tra sau deploy` (toàn bộ trong `Jenkinsfile`).

### B1. Dựng Jenkins container (1 lần)

```powershell
cd D:\Devops\DevOPS-26-13
docker compose -f jenkins\docker-compose.yml up -d --build    # lần đầu ~3–5 phút
```

Mở **http://localhost:8090**. Kiểm tra Jenkins gọi được Docker của máy (DooD):

```powershell
docker exec jenkins docker version --format '{{.Server.Version}}'
# phải ra số version, ví dụ 29.8.1 — nếu trống nghĩa là socket mount hỏng
```

Dừng Jenkins (giữ data, job/credential không mất):

```powershell
docker compose -f jenkins\docker-compose.yml down
```

### B2. Chuẩn bị trên Jenkins (1 lần)

1. **Tạo GitHub PAT:** GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic) → tick `write:packages` + `read:packages` → **copy ngay** (chỉ hiện một lần).
2. **Tạo credential** trên Jenkins 8090: *Manage Jenkins → Credentials → Global → Add Credentials*
   - Kind: **Username with password**
   - ID: **`ghcr-credentials`** (bắt buộc đúng, không có ở đâu khác)
   - Username: tên GitHub (vd `phuoctoan102334`)
   - Password: **PAT** vừa tạo (không phải mật khẩu GitHub)
3. **Tạo job:** *New Item → Pipeline* → phần Pipeline:
   - Definition: **Pipeline script from SCM**
   - Repository URL: `https://github.com/phuoctoan102334/DevOPS-26-13.git`
   - Branch Specifier: **`*/master`**
   - Script Path: **`Jenkinsfile`**

> Chưa có credential `ghcr-credentials` mà bấm Build sẽ fail ngay dòng đầu: `Could not find credentials entry with ID 'ghcr-credentials'` — chưa chạy tới stage nào cả. Tạo credential xong bấm **Build Now** lại là chạy.

### B3. Chạy (mỗi lần)

Vào job → **Build Now** → mở build đang chạy → *Console Output*. Ở mỗi stage sẽ thấy:

| Stage | Dấu hiệu thành công | Cần gì |
|---|---|---|
| Chuan bi | `Image : ghcr.io/<ten>/studentmanager-<...>:master`, `May nay : x86_64` | — |
| BUILD | `docker build` 3 lần, `DONE` | nguồn code |
| TEST | `App san sang sau ...s` + `PASS ...` 8 dòng + `Ket qua: 8 dat, 0 huong` | image local |
| PUSH | `docker login ghcr.io` + 3 lần push + `digest: sha256:...` | PAT |
| PULL | `docker pull` (sau khi đã `docker rmi` bản local) + `linux/amd64` | PAT |
| DEPLOY | `Container studentmanager-prod-*-1 Started` | image trên GHCR |
| Kiem tra sau deploy | `App sẵn sàng sau ...s`, `GET / -> 200`, JSON danh sách sinh viên | app sống |

Cuối pipeline (stage `post.always`) luôn dọn stack test và `docker logout ghcr.io`.

**Kiểm chứng sau 1 lần build thành công:**
1. Console Output thấy JSON danh sách sinh viên.
2. 3 container `studentmanager-prod-*` đang `Up`: `docker ps`
3. http://localhost:3000 hiển thị bảng sinh viên (app chạy từ image **đã kéo về từ registry**).
4. Image có trên GHCR: https://github.com/phuoctoan102334?tab=packages — tag: tên nhánh, commit sha12, và `latest` (khi ở nhánh master).

### B4. Dừng / dọn stack prod

```powershell
docker compose -p studentmanager-prod -f docker-compose.prod.yml down       # giữ data
docker compose -p studentmanager-prod -f docker-compose.prod.yml down -v    # mất data
```

---

## 4. Cách chạy — Kịch bản C: không dùng Jenkins (chạy tay từng bước)

Toàn bộ pipeline chạy được tay bằng PowerShell. `<ten>` là tên GitHub của bạn (viết thường).

### 4.1. BUILD

```powershell
$NS = "ghcr.io/<ten>"
$TAG = "master"
foreach ($c in "backend","frontend","database") {
  docker build --platform linux/amd64 -t "$NS/studentmanager-$c`:$TAG" $c
}
```

### 4.2. TEST (smoke-test 8 phép thử)

Máy này **không có bash chạy được** (lệnh `bash` trỏ vào WSL đang lỗi) nên chạy smoke-test bên trong một container tạm:

```powershell
# 1. Dung stack test (image local, port 13000/18080/11433)
$env:IMAGE_NS = "ghcr.io/<ten>"; $env:IMAGE_TAG = "master"
docker compose -p sms-test -f docker-compose.test.yml up -d

# 2. Chay smoke-test trong container tam (may nay khong co bash hoat dong duoc)
docker run --rm -v ${PWD}:/app -w /app -e BASE_URL=http://host.docker.internal:13000 alpine sh -c "apk add --no-cache curl >/dev/null 2>&1; sh scripts/smoke-test.sh"

# 3. Don stack test
docker compose -p sms-test -f docker-compose.test.yml down -v
```

Đã kiểm chứng thật trên máy này: **8/8 PASS** (cả với app prod đang chạy ở `http://host.docker.internal:3000`). Dòng cuối phải là `=== Ket qua: 8 dat, 0 huong ===`, exit code 0.

> Trong Jenkins thì không cần mẹo này: container Jenkins đã có `bash` + `curl`, nên stage TEST chỉ đơn giản là `BASE_URL="http://host.docker.internal:13000" bash scripts/smoke-test.sh`.

### 4.3. PUSH (cần PAT)

```powershell
# login: dán PAT khi được hỏi, KHÔNG commit PAT vào repo
docker login ghcr.io -u <ten>
foreach ($c in "backend","frontend","database") { docker push "$NS/studentmanager-$c`:$TAG" }
```

### 4.4. PULL — xóa bản local rồi kéo lại (chứng minh image trên registry dùng được)

```powershell
foreach ($c in "backend","frontend","database") {
  docker rmi -f "$NS/studentmanager-$c`:$TAG" 2>$null
  docker pull "$NS/studentmanager-$c`:$TAG"
}
```

### 4.5. DEPLOY + kiểm tra

```powershell
docker compose -p studentmanager-prod -f docker-compose.prod.yml pull
docker compose -p studentmanager-prod -f docker-compose.prod.yml up -d
docker compose -p studentmanager-prod -f docker-compose.prod.yml ps     # chờ database healthy
curl http://localhost:3000/api/students
```

---

## 5. Quy tắc xung đột cổng (đọc trước khi chạy song song)

1. **App dev (`docker compose up -d`) và app prod dùng chung 3000/8080/1433** → chỉ chạy **một trong hai** tại một thời điểm.
2. **Stack TEST (13000/18080/11433) chạy song song được** với cả hai — đó là lý do có cổng riêng.
3. **Jenkins 8090** không đụng app (8080) — đừng đổi 8080 cho Jenkins.
4. **Jenkins Windows 8081** là bản cũ, khác cổng nên không đụng Jenkins container 8090; job cũ `student-manager` đã được tắt trong `config.xml` (cần restart dịch vụ Jenkins với quyền admin để có hiệu lực).
5. Cổng đã bị chiếm → xem ai giữ: `netstat -ano | findstr :3000` rồi `docker ps` (docker giữ thì `docker stop <ten-container>`).

---

## 6. Sự cố thường gặp

| Triệu chứng | Nguyên nhân | Sửa |
|---|---|---|
| `port is already allocated` lúc DEPLOY | Jenkins đang giữ 8080 | Jenkins phải ở **8090** (`jenkins/docker-compose.yml`) |
| `Could not find credentials entry with ID 'ghcr-credentials'` | Chưa tạo credential | Tạo đúng ID `ghcr-credentials` (mục B2) |
| `denied` khi `docker pull ghcr.io/...` | Chưa login, PAT sai, hoặc thiếu `read:packages` | `docker login ghcr.io`, kiểm tra PAT còn hiệu lực |
| `push denied` / `403` | PAT thiếu `write:packages`, hoặc sai namespace | Tạo lại PAT, namespace phải là **chữ thường** |
| Pipeline báo `no matching manifest` | Build `arm64` trên máy x86_64 | Chỉ build `linux/amd64` (máy này là amd64) |
| Smoke test báo `app khong len duoc` | Backend chờ SQL Server, hoặc image test sai tag | `docker compose -p sms-test ps` xem database `healthy` chưa; xem log `docker logs sms-test-backend-1` |
| Jenkins UI không vào được 8090 | Container chưa up | `docker compose -f jenkins\docker-compose.yml up -d`; xem `docker ps` có dòng `0.0.0.0:8090->8080/tcp` |
| `docker` trong Jenkins không chạy | Sai mount socket | Phải mount `/var/run/docker.sock` (named pipe Windows không hoạt động); kiểm chứng bằng `docker exec jenkins docker version` |
| `mvn test` fail `Unable to determine Dialect` | SQL Server chưa chạy | `docker compose up -d database` |
| Job cũ `student-manager` vẫn báo lỗi pipeline Docker Hub | Chưa restart dịch vụ Jenkins Windows | PowerShell admin: `Restart-Service Jenkins` hoặc Disable Project trên UI 8081 |

---

## 7. Tham chiếu nhanh

```powershell
# Dev
docker compose up -d --build
start http://localhost:3000

# Jenkins
docker compose -f jenkins\docker-compose.yml up -d --build
start http://localhost:8090

# Prod từ GHCR (không cần Jenkins)
$env:IMAGE_NS = "ghcr.io/<ten>"; $env:IMAGE_TAG = "master"
docker compose -p studentmanager-prod -f docker-compose.prod.yml up -d

# Dọn hết
docker compose -p sms-test -f docker-compose.test.yml down -v
docker compose -p studentmanager-prod -f docker-compose.prod.yml down -v
```
