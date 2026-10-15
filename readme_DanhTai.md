# Student Management System — Nhánh `DanhTai` (CI/CD với Jenkins)

> README này mô tả **phần bổ sung trên nhánh `DanhTai`**: pipeline Jenkins
> chạy trọn vòng **BUILD → TEST → PUSH → PULL → DEPLOY**.
> Phần ứng dụng (API, giao diện, chạy local bằng Docker) xem `README.md`.
> Hướng dẫn chi tiết từng bước: [`HUONG-DAN-JENKINS.md`](HUONG-DAN-JENKINS.md).

**Stack CI/CD:** Jenkins (container) · Docker Buildx đa kiến trúc · GHCR ·
Docker Compose override · Smoke test tự viết

---

## Những file nhánh này thêm vào

| File | Vai trò |
| --- | --- |
| `Jenkinsfile` | Pipeline 6 stage: BUILD → TEST → PUSH → PULL → DEPLOY → kiểm tra |
| `jenkins/Dockerfile` | Jenkins LTS + docker CLI + Compose v2 + plugin cần sẵn |
| `jenkins/docker-compose.yml` | Dựng Jenkins tại **http://localhost:8090** (cổng 8090 vì 8080 của backend) |
| `docker-compose.prod.yml` | Override `build:` → `image:` — deploy **không build lại**, chạy đúng image đã push/pull |
| `scripts/smoke-test.sh` | Smoke test 10 phép thử trên stack đầy đủ (DB + backend + frontend + CRUD) |
| `HUONG-DAN-JENKINS.md` | Hướng dẫn dựng Jenkins từ đầu + bảng lỗi thường gặp |

```
┌──────────────── laptop (Docker Desktop) ────────────────┐
│  container jenkins :8090 ── docker CLI ──┐              │
│   (Jenkins + buildx)                     │ socket       │
│                                          ▼              │
│                                   Docker Desktop        │
│  student-mgmt-prod-frontend ──► :3000  (nginx + proxy)  │
│  student-mgmt-prod-backend  ──► :8080  (Spring Boot)    │
│  student-mgmt-prod-database ──► :1433  (SQL Server)     │
└─────────────────────────────────────────────────────────┘
                       ▲ push / pull
                        ghcr.io/technology-assassin/student-management-*
```

---

## Cách pipeline hoạt động

| Stage | Việc làm | Bằng chứng "không build lại" |
| --- | --- | --- |
| **Chuẩn bị** | Login GHCR (credential `ghcr-credentials`), cài QEMU, tạo builder buildx | Token không lộ trong log (`--password-stdin`) |
| **1. BUILD** | Build 3 image **native** (amd64) `--load` vào Docker local + cache đẩy lên registry (`:buildcache`) | Lần sau có cache → build nhanh hơn |
| **2. TEST** | Chạy stack smoke bằng 3 image vừa build, 10 phép thử, tự dọn stack + volume khi xong | Dòng `Chế độ: test image co san` |
| **3. PUSH** | Build đa kiến trúc **linux/amd64 + linux/arm64** rồi đẩy 3 image + `:latest` | Bản native lấy lại cache, chỉ arm64 build thêm (QEMU) |
| **4. PULL** | `docker rmi` bản local rồi `docker pull` — ép tải thật từ registry | Giống chính việc server thật sẽ làm |
| **5. DEPLOY** | `docker compose -p student-mgmt-prod -f docker-compose.yml -f docker-compose.prod.yml up -d` | Dùng `image:`, **KHÔNG** `build:`; giữ volume `sqldata` |
| **6. Kiểm tra** | Gọi `host.docker.internal:8080` + `:3000` chờ app thật lên (tối đa 270s) | In JSON API + HTTP 200 |

**Nguyên tắc:** build 1 lần · test trên kiến trúc máy mình trước ·
fail ở stage nào thì **stack đang chạy không bị đụng tới**.

---

## Chạy pipeline

```powershell
# Dựng Jenkins (lần đầu ~3-5 phút)
cd jenkins
docker compose up -d --build      # -> http://localhost:8090

# Kiểm tra Jenkins gọi được Docker
docker exec jenkins docker version --format '{{.Server.Version}} / {{.Server.Arch}}'
```

1. Tạo PAT GitHub (classic, quyền `repo` + `write:packages`) → credential Jenkins:
   ID **`ghcr-credentials`** (Username with password, username = tài khoản của token)
2. Job `student-cicd` → Pipeline from SCM → nhánh **`*/DanhTai`** → Script Path `Jenkinsfile`
3. **Build Now** → xem **Console Output**

### Kết quả tham chiếu (Build #4 — SUCCESS, 8.7 phút)

```
Images : ghcr.io/technology-assassin/student-management-{backend,frontend,database}:1f49d1b
Push   : linux/amd64,linux/arm64
App    : http://localhost:3000   |   http://localhost:8080/api/students
```

### Kích hoạt tự động

Laptop không có IP public nên không nhận webhook — Jenkinsfile khai
`pollSCM('H/2 * * * *')`: cứ 2 phút poll xem có commit mới trên `DanhTai`
hay không, có thì tự chạy pipeline. Hoặc bấm **Build Now** thủ công.

---

## Smoke test — 10 phép thử

1. Frontend trả 200 ở `/` · 2. Trang chủ là HTML thật · 3. Backend `/api/students` trả JSON array ·
4. Nginx proxy `/api/` → backend · 5. `POST` tạo sinh viên · 6. `GET /{id}` đúng dữ liệu ·
7. Tìm kiếm theo tên · 8. `POST update/{id}` · 9. `POST delete/{id}` · 10. Sau xoá GET trả về rỗng

Cổng smoke riêng (3999 / 55999 / 15333) và project name theo `BUILD_NUMBER`
nên **không đụng stack deploy thật**, chạy song song nhiều build cũng được.

Chạy tay từ thư mục gốc:

```bash
SMOKE_IMAGE_BASE=ghcr.io/technology-assassin/student-management \
SMOKE_IMAGE_TAG=1f49d1b ./scripts/smoke-test.sh
```

---

## Rollback về bản trước

Lấy sha của build cũ (Build History hoặc `docker images`), rồi:

```powershell
$env:BACKEND_IMAGE  = "ghcr.io/technology-assassin/student-management-backend:<sha_cũ>"
$env:FRONTEND_IMAGE = "ghcr.io/technology-assassin/student-management-frontend:<sha_cũ>"
$env:DATABASE_IMAGE = "ghcr.io/technology-assassin/student-management-database:<sha_cũ>"
$env:FRONTEND_PORT = "3000"; $env:BACKEND_PORT = "8080"; $env:DB_PORT = "1433"
$env:MSSQL_SA_PASSWORD = "SA_Passw0rd1"

docker compose -p student-mgmt-prod -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## Bảng ports

| Cổng | Ai dùng |
| --- | --- |
| 8090 | Giao diện Jenkins |
| 3000 | Frontend app (deploy thật) |
| 8080 | Backend app (deploy thật) |
| 1433 | SQL Server (deploy thật) |
| 3999 / 55999 / 15333 | Smoke test (tự dọn sau mỗi lần) |
| 50000 | Jenkins agent (để sẵn, chưa dùng) |

---

## Lưu ý đặc thù của nhánh này

- **Namespace GHCR = org `Technology-Assassin`** (viết thường trong
  `IMAGE_NAME`): tài khoản cá nhân `DanhTaiSeck` bị GHCR từ chối
  (`denied: not_found: owner not found` — đã test kỹ, không phải do pipeline),
  org thì push ngon. Muốn đổi sang tên khác chỉ cần sửa 1 dòng `IMAGE_NAME`
  trong `Jenkinsfile`.
- Yêu cầu **Docker Compose ≥ 2.24** (`!reset`/`!override` trong
  `docker-compose.prod.yml`) — Docker Desktop hiện tại đã đáp ứng.
- Lần build đầu tiên chậm nhất (Maven arm64 chạy dưới QEMU ~5–10 phút);
  timeout đã đặt 45 phút. Lần sau có cache nhanh hơn nhiều.
- Lỗi thường gặp → bảng đầy đủ trong [`HUONG-DAN-JENKINS.md`](HUONG-DAN-JENKINS.md).

---

## Dọn dẹp

```powershell
# Dừng app deploy (giữ dữ liệu)
docker compose -p student-mgmt-prod -f docker-compose.yml -f docker-compose.prod.yml down

# Dừng Jenkins (giữ job/lịch sử)
cd jenkins; docker compose down

# Xoá luôn dữ liệu Jenkins
docker compose down -v
```
