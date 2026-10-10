# Nhật Ký Thay Đổi (nhatky.md)

[2026-09-26 07:52] Thấp | .gitignore, cautruc.md | Bootstrap theo luat.md: backup, ignore .backup/, tạo snapshot | OK
[2026-09-26 08:06] Cao | pom.xml, index.html, WebConfig.java | Tach 3 folder theo xac nhan Y, them CORS; compile OK, test can DB | OK
[2026-09-26 08:40] TB | Dockerfile, docker-compose.yml, nginx.conf | Them Docker 3 tang + fix healthcheck quote, compose up, API 200 | OK
[2026-09-26 08:44] Thấp | README.md | Viết hướng dẫn build + chạy (Docker/local) theo yêu cầu | OK
[2026-09-26 10:27] TB | ci-ghcr.yml, cautruc.md | Them GitHub Actions: test + build/push image GHCR moi commit | OK
[2026-10-10 07:24] Thấp | cautruc.md, nhatky.md | Nạp phiên theo luat.md: snapshot hết hạn 7 ngày, quét lại & cập nhật | OK
[2026-10-10 07:35] TB | Jenkinsfile, docker-compose.deploy.yml, README.md | Them Jenkins CI/CD: test Maven + push Docker Hub + deploy | OK
[2026-10-10 10:17] TB | Jenkinsfile | Fix ready-check SQL Server (doi log docker, bo TCP false-positive cua Docker Desktop proxy), kiem CI DB truoc test, post giu log truoc khi xoa | OK (backup .backup/Jenkinsfile/Jenkinsfile.bak.20261010_1015)
[2026-10-10 10:52] Cao | .gitattributes | Them *.sh text eol=lf — entrypoint-init.sh checkout CRLF (autocrlf=true) lam container Docker exec that bai, chan Jenkinsfile CI | OK (backup .backup/.gitattributes/.gitattributes.bak.20261010_1051)
[2026-10-10 11:00] TB | Jenkinsfile | Fix docker login: PS5.1 pipe them CRLF → password con \r; dung bash printf "%s" (Git for Windows); credential Docker Hub van hop le (token 200) | OK (backup .backup/Jenkinsfile/Jenkinsfile.bak.20261010_1059)
