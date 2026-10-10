# Cấu Trúc Dự Án (cautruc.md)
Cập nhật lúc: 2026-10-10 07:35
Stack: Java 21 / Spring Boot 3.4.1 (Maven) + Thymeleaf + JPA + SQL Server

## Tổng quan
Quản lý sinh viên (LAB 03), đã tách 3 phần rõ ràng: backend (Spring Boot REST + view Thymeleaf), frontend (HTML thuần gọi REST API, chạy riêng), database (script SQL).

## Cây thư mục chính
- backend/ — project Maven Spring Boot (build từ đây)
  - pom.xml, mvnw, mvnw.cmd, .mvn/wrapper/ — build config
  - src/main/java/com/example/studentmanager/
    - SchoolmanagerApplication.java — main()
    - config/WebConfig.java — CORS cho frontend chạy riêng gọi API
    - controller/ — StudentController (view Thymeleaf /students), StudentRestController (REST /api/students)
    - service/, repository/, entity/ — business logic, JPA, entity Student
  - src/main/resources/ — application.properties (chứa credentials DB), templates/students.html (Thymeleaf)
  - src/test/java/.../StudentmanagerApplicationTests.java — contextLoads test (cần SQL Server chạy mới pass)
  - target/ — build output (ignored)
- frontend/ — index.html: SPA thuần JS/CSS gọi fetch /api/students, chạy riêng (Live Server hoặc mở trực tiếp)
- database/ — database-setup.sql (tạo bảng students + data mẫu), sql.md (tài liệu SQL)
- luat.md — quy tắc hoạt động của AI (đọc trước tiên mỗi phiên)
- cautruc.md — snapshot cấu trúc này
- nhatky.md — nhật ký cô đọng các thay đổi
- README.md — hướng dẫn build + chạy dự án (Docker và local), bảng REST API, mục CI/CD Jenkins
- docker-compose.yml — orchestrate 3 container: database (SQL Server 2022), backend (port 8080), frontend (port 3000); volume sqldata giữ data
- Jenkinsfile — Jenkins CI/CD trên Windows agent: SQL Server container → mvnw test → docker login/push Docker Hub (<user>/studentmanager-*) → stage Deploy (nhánh main/master)
- docker-compose.deploy.yml — deploy stack từ image Docker Hub (pull, không build); dùng chung volume sqldata/port với docker-compose.yml, chỉ chạy 1 trong 2
- backend/Dockerfile (+ .dockerignore) — multi-stage Maven build → JRE 21, chạy jar Spring Boot
- frontend/Dockerfile (+ nginx.conf) — nginx serve index.html, proxy /api/ → backend:8080
- database/Dockerfile (+ entrypoint-init.sh) — SQL Server 2022, tự tạo DB school + bảng students khi khởi động (idempotent)
- image_thinh/ — ảnh chụp màn hình hướng dẫn (ubuntu/ssh), không liên quan app
- giuaky_thinh/ — KHÔNG đọc, KHÔNG sửa, KHÔNG xóa (theo yêu cầu người dùng; để nguyên trạng)
- .backup/ — backup tập trung trước khi sửa file (gitignored)
- .gitignore, .gitattributes — cấu hình git ở gốc
- .github/workflows/ci-ghcr.yml — CI: mỗi push → test backend (Maven 21 + SQL Server container tự tạo DB school) → build & push image backend/frontend/database lên ghcr.io (GITHUB_TOKEN, tag: branch, sha, latest)
- .github/modernize/java-upgrade/ — log/kế hoạch agent nâng cấp Java tự động (không thuộc app)
- .vscode/settings.json — cấu hình Java cho VS Code

## Entry points quan trọng
- backend/src/main/java/.../SchoolmanagerApplication.java — main() khởi động app
- backend/.../controller/StudentRestController.java — REST: GET/POST /api/students, /{id}, /search, /update/{id}, /delete/{id}
- backend/.../controller/StudentController.java — GET /students render.students.html
- backend/.../config/WebConfig.java — addCorsMappings cho /api/**
- backend/src/main/resources/application.properties — spring.datasource.* (SQL Server localhost:1433, KHÔNG in giá trị ra log)
- frontend/index.html — UI chính (const API = '/api/students')

## Database / Schema liên quan (nếu có)
- students (SQL Server, database `school`) — id INT PK, name NVARCHAR(100), age INT, email NVARCHAR(100); ddl-auto=none, schema do database/database-setup.sql quản lý

## Ghi chú rủi ro/đặc thù
- Build trên máy này: JAVA_HOME chưa set — dùng JDK c:\oracleJdk-27 (javac 27) + Maven wrapper cache tại ~/.m2/wrapper/dists/apache-maven-3.9.12; máy không có JDK/Maven cài sẵn
- `mvn test` fail ("Unable to determine Dialect") khi SQL Server localhost:1433 chưa chạy — lỗi môi trường, không phải lỗi code
- CORS WebConfig dùng allowedOriginPatterns("*") — chỉ chấp nhận cho lab local không auth; sửa auth/payment = mức Cao, cần Y/N
- Chạy backend từ thư mục backend/ (mvnw spring-boot:run); frontend mở frontend/index.html bằng Live Server
- Chạy hết bằng Docker (khuyên dùng): `docker compose up -d` — frontend http://localhost:3000, API http://localhost:8080/api/students, SQL Server localhost:1433; dừng: `docker compose down` (giữ data), `down -v` (mất data)
- Mật khẩu SA mặc định trong compose: `SA_Passw0rd1` (đổi qua biến môi trường MSSQL_SA_PASSWORD trước khi up; backend tự nhận qua env SPRING_DATASOURCE_*)
- application.properties chứa tài khoản/mật khẩu DB — không in log/commit giá trị thật
- Đổi schema database, xóa file/table = mức Cao, cần xác nhận Y/N
- Git: repo báo "dubious ownership" với lệnh git thường — chỉ chạy được với `git -c safe.directory=D:/Devops/DevOPS-26-13 ...` (KHÔNG ghi safe.directory vào config global nếu chưa được yêu cầu). Nhánh hiện tại: `thinh-upp`; file chưa track: .github/, cautruc.md, luat.md, nhatky.md
- Trạng thái runtime (lần ghi nhận gần nhất 2026-09-26): container Docker đã dừng tất cả — chạy lại bằng `docker compose up -d`
