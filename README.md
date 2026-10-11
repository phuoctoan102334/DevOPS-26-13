# Student Management System — Quản lý Sinh viên

Ứng dụng quản lý sinh viên (LAB 03): REST API + giao diện web, dữ liệu lưu trên SQL Server.

**Stack:** Java 21 · Spring Boot 3.4.1 · Spring Data JPA · Thymeleaf · SQL Server 2022 · Docker

## Cấu trúc dự án

```
├── backend/     ← API + server Spring Boot (Maven)
├── frontend/    ← index.html (giao diện thuần JS gọi REST API)
├── database/    ← script SQL (database-setup.sql) + Dockerfile SQL Server
├── jenkins/     ← Dockerfile + compose dựng Jenkins trong container (Bài 2)
├── scripts/     ← smoke-test.sh (8 phép thử, dùng trong stage TEST)
├── docker-compose.yml        ← dev local (build từ source)
├── docker-compose.test.yml   ← stage TEST (image local, port 13000/18080/11433)
├── docker-compose.prod.yml   ← stage DEPLOY (pull image từ GHCR)
├── Jenkinsfile               ← pipeline BUILD → TEST → PUSH → PULL → DEPLOY
```

---

## Cách 1: Chạy bằng Docker (khuyên dùng)

**Yêu cầu:** Docker Desktop đã cài và khởi động.

```bash
# Build 3 image + chạy toàn bộ (database, backend, frontend)
docker compose up -d

# Xem trạng thái
docker compose ps

# Dừng (giữ nguyên dữ liệu)
docker compose down

# Dừng và xóa sạch dữ liệu SQL Server
docker compose down -v
```

Sau khi chạy, truy cập:

| Dịch vụ | URL / Port |
|---|---|
| Frontend (giao diện) | http://localhost:3000 |
| Backend (REST API) | http://localhost:8080/api/students |
| SQL Server | localhost:1433 |

- Container `database` tự chạy `database-setup.sql`: tạo database `school`, bảng `students` + dữ liệu mẫu khi khởi động (bỏ qua nếu đã tồn tại).
- Kiểm tra nhanh: mở http://localhost:3000 → bảng sinh viên tự tải; hoặc `curl http://localhost:8080/api/students`.
- Đổi mật khẩu SA: đặt biến môi trường `MSSQL_SA_PASSWORD` trước khi `up` (giá trị mặc định xem trong `docker-compose.yml`); backend tự đọc qua `SPRING_DATASOURCE_*`.

**Chỉ build lại 1 service:** `docker compose build backend` (hoặc `frontend`, `database`), sau đó `docker compose up -d`.

---

## Build project

```bash
# Build backend thành file .jar (từ thư mục backend/)
mvnw.cmd -DskipTests package
# → backend/target/studentmanager-0.0.1-SNAPSHOT.jar

# Chạy file jar (cần cấu hình datasource trước)
java -jar target/studentmanager-0.0.1-SNAPSHOT.jar

# Build toàn bộ image Docker (từ thư mục gốc)
docker compose build
```

**Build trên máy dev này:** máy không có JDK/Maven cài sẵn — dùng JDK tại `c:\oracleJdk-27` và Maven wrapper cache trong `~/.m2/wrapper/dists`, hoặc đơn giản nhất: build bằng Docker (`docker compose build`) không cần JDK local.

---

## REST API

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/api/students` | Lấy danh sách sinh viên |
| GET | `/api/students/{id}` | Lấy sinh viên theo ID |
| GET | `/api/students/search?name=...` | Tìm theo tên |
| POST | `/api/students` | Thêm sinh viên (JSON body) |
| POST | `/api/students/update/{id}` | Cập nhật sinh viên |
| POST | `/api/students/delete/{id}` | Xóa sinh viên |

Body mẫu:

```json
{ "id": 4, "name": "Nguyễn Văn D", "age": 21, "email": "d@gmail.com" }
```

---

## CI/CD bằng Jenkins (Bài 2: BUILD → TEST → PUSH → PULL → DEPLOY)

> **Bảng cổng đầy đủ + cách chạy từng kịch bản (dev / pipeline Jenkins / chạy tay không Jenkins): xem [`run.md`](run.md).**

Toàn bộ pipeline nằm ở `Jenkinsfile` (root), chạy trong **container Jenkins** (xem `jenkins/`) điều khiển Docker của laptop qua socket — kiểu **DooD** (Docker outside of Docker). Cuối pipeline, app chạy thật ở **http://localhost:3000** từ image **đã kéo về từ registry**, không phải image local.

```
Chuẩn bị → BUILD (3 image) → TEST (smoke-test 8 phép thử) → PUSH (GHCR)
→ PULL (docker rmi + docker pull) → DEPLOY (compose.prod) → Kiểm tra sau deploy
```

**Vì sao có stage PULL:** image vừa build đang nằm sẵn trên máy. Nếu deploy bằng image local, bạn không chứng minh được image trên registry dùng được (lỡ push hỏng/thiếu layer — deploy vẫn chạy ngon nhưng server thật kéo về sẽ chết). Nên PULL cố tình `docker rmi` bản local rồi mới `docker pull`, ép Docker tải thật từ registry.

### Dựng Jenkins (1 lần)

```bash
cd jenkins
docker compose up -d --build     # lần đầu ~3–5 phút
```

Mở **http://localhost:8090** — vào thẳng giao diện, không hỏi mật khẩu (đã tắt setup wizard). (Dùng 8090 chứ không phải 8080, vì 8080 là cổng backend của app — nếu Jenkins giữ 8080 thì stage DEPLOY sẽ lỗi *port is already allocated*.) Kiểm tra Jenkins gọi được Docker:

```bash
docker exec jenkins docker version --format '{{.Server.Version}}'
# phải ra số version, ví dụ 29.8.1
```

### Chuẩn bị trên Jenkins (1 lần)

1. Tạo **GitHub PAT**: Settings → Developer settings → Personal access tokens → Tokens (classic) → tick `write:packages` + `read:packages` → copy ngay (chỉ hiện một lần).
2. Tạo credential **`ghcr-credentials`** (loại *Username with password*): Username = tên GitHub, Password = **PAT** vừa tạo (không phải mật khẩu GitHub). ID phải đúng `ghcr-credentials`.
3. Tạo job **Pipeline** (New Item → Pipeline), phần Pipeline chọn:
   - Definition: **Pipeline script from SCM**
   - Repository URL: `https://github.com/<TÊN_GITHUB>/DevOPS-26-13.git`
   - Branch Specifier: `*/master`
   - Script Path: `Jenkinsfile`

### Kết quả mỗi lần build

- Image push lên GHCR: `ghcr.io/<user>/studentmanager-backend|frontend|database` với tag: tên nhánh, commit sha12, và `latest` (nhánh `master`).
- **Tự động deploy** bằng `docker-compose.prod.yml` (chỉ `image:`, không `build:`) — stack chạy từ image vừa kéo về.
- Mở **http://localhost:3000** → app đã đi trọn vòng build → test → push → pull → deploy.

### 3 file compose, mỗi file một vai trò

| File | Dùng khi | Nguồn image |
|---|---|---|
| `docker-compose.yml` | Dev local (`docker compose up -d`) | `build:` từ source |
| `docker-compose.test.yml` | Stage **TEST** trong pipeline | image local vừa build (`pull_policy: never`), port rieng 13000/18080/11433 |
| `docker-compose.prod.yml` | Stage **DEPLOY** / deploy tay | pull từ GHCR (`pull_policy: always`) |

Cả ba dùng chung volume `sqldata` và port 1433/8080/3000 (riêng file test dùng port khác) — chỉ chạy 1 trong 2 tại một thời điểm.

**Deploy tay bằng image từ registry** (không cần Jenkins):

```powershell
$env:IMAGE_NS = "ghcr.io/<user-github>"
$env:IMAGE_TAG = "master"          # hoặc tên nhánh / sha12
docker compose -p studentmanager-prod -f docker-compose.prod.yml up -d
```

- Mật khẩu DB: đặt biến `MSSQL_SA_PASSWORD` (mặc định trong compose); PAT GitHub chỉ nằm trong Jenkins, không commit vào repo.
- **Nếu chưa tạo credential `ghcr-credentials`**: pipeline sẽ fail ngay ở dòng đầu tiên (`Could not find credentials entry with ID 'ghcr-credentials'`) — chưa chạy tới stage nào cả. Tạo xong credential rồi bấm **Build Now** lại là được.
- **Sau khi build xong, kiểm chứng 4 điểm:** (1) mục *Test Report*/console thấy `App sẵn sàng sau ...s` + JSON danh sách sinh viên; (2) image đã có trên GHCR: https://github.com/phuoctoan102334?tab=packages; (3) `docker ps` thấy 3 container `studentmanager-prod-*`; (4) http://localhost:3000 hiển thị bảng sinh viên.
- **Lưu ý kiến trúc:** máy này là x86_64 và image SQL Server 2022 chỉ có manifest `linux/amd64` — nên pipeline chỉ build/push `linux/amd64` (không multi-arch như bản macOS-arm64 trong hướng dẫn gốc).
