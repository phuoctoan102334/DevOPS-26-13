# Cấu Trúc Dự Án (cautruc.md)
Cập nhật lúc: 2026-10-11 16:00
Stack: Java 21 / Spring Boot 3.4.1 (Maven) + Thymeleaf + JPA + SQL Server

## Tổng quan
Quản lý sinh viên (LAB 03), đã tách 3 phần rõ ràng: backend (Spring Boot REST + view Thymeleaf), frontend (HTML thuần gọi REST API, chạy riêng), database (script SQL). CI/CD bằng Jenkins trong container theo Bài 2: BUILD → TEST → PUSH → PULL → DEPLOY, registry GHCR.

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
- run.md — bảng cổng đầy đủ (3000/8080/1433 dev+prod, 13000/18080/11433 test, Jenkins 8090+50000, Jenkins Windows 8081) + cách chạy từng kịch bản A/B/C và bảng sự cố
- docker-compose.yml — orchestrate 3 container: database (SQL Server 2022), backend (port 8080), frontend (port 3000); volume sqldata giữ data
- docker-compose.test.yml — stage TEST của pipeline: chạy 3 image local vừa build (pull_policy: never), port rieng 11433/18080/13000, project name sms-test, down -v sau mỗi lần
- docker-compose.prod.yml — stage DEPLOY: pull image từ GHCR (pull_policy: always), project name studentmanager-prod, port chuẩn 1433/8080/3000
- ~~docker-compose.deploy.yml~~ — ĐÃ XÓA (2026-10-11): bản cũ deploy bằng Docker Hub, thay bằng docker-compose.prod.yml (GHCR). Bản lưu tại `.backup/docker-compose.deploy.yml/`
- Jenkinsfile — pipeline Jenkins (Bài 2): stage Chuan bị → BUILD → TEST (smoke-test) → PUSH (GHCR) → PULL (rmi + pull) → DEPLOY → Kiem tra sau deploy; agent = container Jenkins Linux nên viết bằng sh, không phải powershell
- jenkins/Dockerfile — từ jenkins/jenkins:lts-jdk17, cài docker CLI + compose + buildx + git/curl, tắt setup wizard, cài sẵn plugin git/pipeline/credentials
- jenkins/docker-compose.yml — container jenkins (UI port **8090**, agent 50000), DooD: mount /var/run/docker.sock, group_add ["0"] (socket root:root 660), extra_hosts host-gateway; volume jenkins_home. Đổi từ 8080 → 8090 vì 8080 là cổng backend của app (giữ 8080 cho app theo hướng dẫn)
- scripts/smoke-test.sh — 8 phép thử (frontend 200, API 200, data seed, get by id, search, POST add, count tăng, delete) — đã chạy thật: 8/8 PASS
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
- Git: repo báo "dubious ownership" với lệnh git thường — chỉ chạy được với `git -c safe.directory=D:/Devops/DevOPS-26-13 ...` (KHÔNG ghi safe.directory vào config global nếu chưa được yêu cầu). Branch mặc định của repo là `master` (không phải main). File chưa track: .github/, luat.md, huong-dan-jenkins.md, jenkins/, scripts/, docker-compose.test.yml, docker-compose.prod.yml; thay đổi riêng của user trong image_thinh/ chưa commit
- **Máy này x86_64 (amd64), KHÔNG phải arm64** như máy macOS trong hướng dẫn gốc → pipeline chỉ build/push `linux/amd64`; SQL Server 2022 không có manifest arm64 nên multi-arch sẽ fail "no matching manifest"
- Docker Desktop trên máy này: socket mount `/var/run/docker.sock` vào container HOẠT ĐỘNG (đã kiểm chứng); named pipe `//./pipe/docker_engine` mount thành file rỗng → KHÔNG dùng; `host.docker.internal` resolve được (192.168.65.254 / fdc4:...::254)
- Host Windows này KHÔNG có `bash` hoạt động (WSL relay lỗi "execvpe(/bin/bash)") → smoke-test phải chạy từ trong container; các lệnh sh trong pipeline đều chạy trong container Jenkins nên không ảnh hưởng
- **Jenkins trên máy có 2 bản:** (1) Jenkins Windows service gốc tại `C:\Program Files\Jenkins` — port **8081**, job multibranch `student-manager` + credential `dockerhub-cred`/`github-pat`, dùng cho pipeline cũ — **đã set `<disabled>true</disabled>` trong config.xml** (backup `config.xml.bak.20261011_1540`) nhưng **cần restart dịch vụ Jenkins với quyền admin** mới có hiệu lực (không có quyền restart từ phiên này); (2) Jenkins **container** mới (Bài 2) — port **8090**, dùng credential `ghcr-credentials`. Job mới phải tạo trên Jenkins container.
- Docker Hub credential cũ `dockerhub-cred` (trong Jenkins Windows 8081) không còn dùng — GIỮ LẠI, không xóa (chỉ file docker-compose.deploy.yml đã xóa theo xác nhận Y/N)
- Trạng thái runtime (lần ghi nhận 2026-10-11 15:05): Docker Desktop chạy; container `jenkins` chạy (UI 8090, agent 50000, Jenkins URL đã set `http://localhost:8090/`); stack **prod đang chạy** ở 3000/8080/1433 (project `studentmanager-prod`, image đã deploy qua registry cục bộ); 3 image local `ghcr.io/phuoctoan102334/studentmanager-*:master`; registry tạm `localhost:5000` + stack test sms-test đã dọn sạch
- Chưa chạy được pipeline TRONG Jenkins: thiếu credential `ghcr-credentials` (cần GitHub PAT có `write:packages`/`read:packages` — người dùng tự tạo) và job Pipeline chưa tạo
