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
[2026-10-10 11:06] TB | Jenkinsfile | Fix Groovy: Jenkins CPS xu ly \ la escape ngay ca trong '' (build #14 loi compile); dung slash xuôi C:/Program Files/...; test plumbing bash printf OK | OK (backup .backup/Jenkinsfile/Jenkinsfile.bak.20261010_1105)
[2026-10-11 13:40] Cao | Jenkinsfile, jenkins/Dockerfile, jenkins/docker-compose.yml, docker-compose.test.yml, docker-compose.prod.yml, scripts/smoke-test.sh, README.md | Lam lai bai 2 theo huong dan: DooD, 6 stage BUILD-TEST-PUSH-PULL-DEPLOY, chuyen GHCR | OK (backup .backup/Jenkinsfile/Jenkinsfile.bak.20261011_1305, .backup/README.md/README.md.bak.20261011_1305)
[2026-10-11 13:45] TB | scripts/smoke-test.sh, docker-compose.test.yml | Kiem thu thuc te: build 3 image, stack test port 13000, smoke-test 8/8 PASS, Jenkins container goi duoc Docker 29.8.1 | OK
[2026-10-11 14:20] Cao | jenkins/docker-compose.yml, README.md, cautruc.md | Doi Jenkins UI 8080 -> 8090: 8080 can giu cho backend cua app (theo huong dan), neu khong stage DEPLOY loi "port is already allocated"; dat lai Jenkins URL; validate lai Jenkinsfile | OK
[2026-10-11 15:05] TB | (khong doi file) | Kiem thu pipeline: declarative-linter PASS; chay that 5 stage tu trong container Jenkins - BUILD, TEST smoke 8/8, PUSH, PULL (rmi+pull, linux/amd64), DEPLOY + check sau deploy dung registry cuc bo localhost:5000; app song o localhost:3000; da don registry/stack tam | OK (con lai: push GHCR that + tao job Jenkins can PAT tu nguoi dung)
[2026-10-11 15:30] TB | Jenkinsfile | Giai backslash noi dong trong 2 khoi sh (build/rmi), dat ten stage "Chuan bi" de tranh bai escape cua Jenkins CPS; linter PASS, chay thu lenh BUILD trong container OK
[2026-10-11 15:45] Cao | docker-compose.deploy.yml | Xoa file deploy Docker Hub cu theo xac nhan Y/N; thay bang docker-compose.prod.yml (GHCR); cap nhat cautruc.md, README.md (them cach xu ly thieu credential + 4 diem kiem tra sau build)
[2026-10-11 15:45] Cao | C:\ProgramData\Jenkins\.jenkins\jobs\student-manager\config.xml | Tat job multibranch cu (disabled true) de khong chay pipeline Docker Hub khi push Jenkinsfile moi; backup config.xml.bak.20261011_1540; CHUA co hieu luc vi khong co quyen admin de restart dich vu Jenkins - nguoi dung can restart thu cong
[2026-10-11 16:00] TB | run.md, README.md, cautruc.md | Them run.md: bang cong day du (dev 3000/8080/1433, test 13000/18080/11433, Jenkins 8090+50000, Jenkins Windows 8081) + cach chay A/B/C + bang su co; link tu README; kiem chung smoke-test trong container alpine: 8/8 PASS
[2026-10-11 16:25] TB | Jenkinsfile, README.md, run.md, jenkins/, scripts/, docker-compose.test.yml, docker-compose.prod.yml | Commit Bai 2 vao nhanh thinh-upp (khong commit image_thinh/ - thay doi rieng cua user) | OK
