# Student Management System — Quản lý Sinh viên

Ứng dụng quản lý sinh viên (LAB 03): REST API + giao diện web, dữ liệu lưu trên SQL Server.

**Stack:** Java 21 · Spring Boot 3.4.1 · Spring Data JPA · Thymeleaf · SQL Server 2022 · Docker

## Cấu trúc dự án

```
├── backend/     ← API + server Spring Boot (Maven)
├── frontend/    ← index.html (giao diện thuần JS gọi REST API)
├── database/    ← script SQL (database-setup.sql) + Dockerfile SQL Server
├── docker-compose.yml
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

## CI/CD bằng Jenkins

Pipeline nằm ở `Jenkinsfile` (root), chạy trên agent **Windows** (Docker Desktop đang chạy). luồng công việc:

```
Checkout (GitHub) → SQL Server container → mvn test (backend)
→ docker login Docker Hub → build & push 3 image → deploy bằng docker-compose.deploy.yml
```

**Chuẩn bị trên Jenkins (1 lần):**

1. Cài plugin: **Pipeline**, **Git**.
2. Tạo credential **`dockerhub-cred`** (loại *Username with password*):
   - Username: user Docker Hub
   - Password: Personal Access Token (PAT) tạo tại https://hub.docker.com → Account Settings → Personal access tokens (quyền *Read & Write*)
3. Tạo job **Multibranch Pipeline** trỏ vào repo GitHub này (Jenkinsfile ở root sẽ tự được đọc).
4. Agent Windows cần: Docker Desktop đang chạy, `git` trong PATH; JDK mặc định pipeline dùng `C:\oracleJdk-27` (đổi biến `JDK_FALLBACK` trong `Jenkinsfile` nếu máy khác).

**Kết quả mỗi lần build:**

- Image push lên Docker Hub: `<user>/studentmanager-backend|frontend|database` với tag: tên nhánh, commit sha12, và `latest` (nhánh `main`/`master`).
- Ở nhánh `main`/`master`: stage **Deploy tự động** — `docker compose -f docker-compose.deploy.yml pull && up -d` (chạy stack từ image vừa push, không build lại source).
- Nhánh khác: chỉ test + build + push, không deploy.

**Deploy tay bằng image từ registry** (không cần Jenkins):

```powershell
$env:IMAGE_NS = "<user-dockerhub>"
$env:IMAGE_TAG = "latest"          # hoặc tên nhánh / sha12
docker compose -f docker-compose.deploy.yml up -d
```

- `docker-compose.yml` (build từ source) và `docker-compose.deploy.yml` (pull image) dùng chung volume `sqldata` và các port 1433/8080/3000 — chỉ chạy 1 trong 2 tại một thời điểm.
- Mật khẩu DB: đặt biến `MSSQL_SA_PASSWORD` (mặc định trong compose); credential Docker Hub chỉ nằm trong Jenkins, không commit vào repo.
