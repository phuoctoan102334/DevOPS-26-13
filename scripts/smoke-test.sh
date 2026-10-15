#!/usr/bin/env bash
# ===================================================================
# Smoke test cho Student Management System
#
# Chạy stack đầy đủ (database + backend + frontend) từ image ĐÃ BUILD
# sẵn trên registry/local — compose KHÔNG build lại — rồi thử CRUD API
# qua cả backend lẫn nginx proxy.
#
# Jenkins truyờng hai biến (bắt buộc):
#   SMOKE_IMAGE_BASE  vd: ghcr.io/phuoctoan102334/student-management
#   SMOKE_IMAGE_TAG   vd: a1b2c3d   (sha short)
#
# Chạy tay từ thư mục gốc dự án:
#   SMOKE_IMAGE_BASE=ghcr.io/<user>/student-management \
#   SMOKE_IMAGE_TAG=latest ./scripts/smoke-test.sh
#
# Cổng smoke cố tình khác cổng deploy thật (3000/8080/1433) để hai stack
# không đụng nhau. Script tự dọn stack + volume DB khi thoát.
# ===================================================================
set -u

: "${SMOKE_IMAGE_BASE:?Thieu SMOKE_IMAGE_BASE, vi du: ghcr.io/phuoctoan102334/student-management}"
: "${SMOKE_IMAGE_TAG:?Thieu SMOKE_IMAGE_TAG, vi du: a1b2c3d}"

SMOKE_PROJECT="${SMOKE_PROJECT:-student-smoke}"
SMOKE_HOST="${SMOKE_HOST:-host.docker.internal}"

FE_PORT=3999
BE_PORT=55999
DB_PORT=15333
MSSQL_SA_PASSWORD="${MSSQL_SA_PASSWORD:-SA_Passw0rd1}"

# Biến mà docker-compose.prod.yml đọc (export để compose thấy)
export BACKEND_IMAGE="${SMOKE_IMAGE_BASE}-backend:${SMOKE_IMAGE_TAG}"
export FRONTEND_IMAGE="${SMOKE_IMAGE_BASE}-frontend:${SMOKE_IMAGE_TAG}"
export DATABASE_IMAGE="${SMOKE_IMAGE_BASE}-database:${SMOKE_IMAGE_TAG}"
export FRONTEND_PORT="$FE_PORT"
export BACKEND_PORT="$BE_PORT"
export DB_PORT
export MSSQL_SA_PASSWORD

compose() {
  docker compose -p "$SMOKE_PROJECT" \
    -f docker-compose.yml -f docker-compose.prod.yml "$@"
}

cleanup() {
  # -v: xoá volume DB của smoke để lần chạy sau luôn bắt đầu sạch
  compose down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

PASS=0
FAIL=0
ok()  { echo "  PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Che do: test image co san -> ${BACKEND_IMAGE}"
echo "    (compose KHONG build lai - day la bang chung khong build lai)"

echo "--- Khoi dong stack smoke (DB se mat ~40-60s moi lan vi tao volume moi)..."
if ! compose up -d --remove-orphans; then
  echo "Loi khi compose up"
  compose ps
  exit 1
fi

echo "--- Cho backend ket noi duoc SQL Server (toi da 300s)..."
READY=0
for i in $(seq 1 150); do
  if curl -sf "http://${SMOKE_HOST}:${BE_PORT}/api/students" >/dev/null 2>&1; then
    READY=1
    echo "Backend san sang sau ~${i}s"
    break
  fi
  sleep 2
done
if [ "$READY" != "1" ]; then
  echo "TIMEOUT - backend khong phan hoi sau 300s"
  compose ps
  compose logs backend | tail -60
  exit 1
fi

BASE_FE="http://${SMOKE_HOST}:${FE_PORT}"
BASE_BE="http://${SMOKE_HOST}:${BE_PORT}"

# --- 1. Frontend tra loi ---
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_FE/")
[ "$CODE" = "200" ] && ok "Frontend tra 200 o /" || bad "Frontend tra $CODE o /"

# --- 2. Trang chu la HTML that ---
if curl -s "$BASE_FE/" | grep -qi '<html'; then
  ok "Trang chu la HTML that"
else
  bad "Trang chu khong phai HTML"
fi

# --- 3. Backend tra JSON array ---
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_BE/api/students")
BODY=$(curl -s "$BASE_BE/api/students")
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q '^\['; then
  ok "Backend /api/students tra JSON array"
else
  bad "Backend /api/students: HTTP $CODE, body: $(echo "$BODY" | head -c 200)"
fi

# --- 4. Nginx proxy /api/ -> backend ---
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_FE/api/students")
[ "$CODE" = "200" ] && ok "Nginx proxy /api/ -> backend hoat dong" || bad "Proxy tra HTTP $CODE"

# --- 5. CRUD: them sinh vien ---
#   (id khong @GeneratedValue nen client phai gui id)
CREATED=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"id":9001,"name":"Jenkins Smoke","age":21,"email":"smoke@test.local"}' \
  "$BASE_BE/api/students")
if echo "$CREATED" | grep -q "Jenkins Smoke"; then
  ok "POST /api/students tao duoc sinh vien"
else
  bad "POST tao sinh vien: $(echo "$CREATED" | head -c 200)"
fi

# --- 6. Lay sinh vien theo id ---
BODY=$(curl -s "$BASE_BE/api/students/9001")
echo "$BODY" | grep -q "Jenkins Smoke" \
  && ok "GET /api/students/9001 dung du lieu" || bad "GET theo id: $(echo "$BODY" | head -c 200)"

# --- 7. Tim kiem theo ten ---
BODY=$(curl -s "$BASE_BE/api/students/search?name=Jenkins")
echo "$BODY" | grep -q "9001" \
  && ok "Tim kiem theo ten hoat dong" || bad "Search: $(echo "$BODY" | head -c 200)"

# --- 8. Cap nhat sinh vien ---
UPDATED=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"name":"Jenkins Updated","age":22,"email":"updated@test.local"}' \
  "$BASE_BE/api/students/update/9001")
if echo "$UPDATED" | grep -q "Jenkins Updated"; then
  ok "POST /api/students/update/{id} hoat dong"
else
  bad "Update: $(echo "$UPDATED" | head -c 200)"
fi

# --- 9. Xoa sinh vien ---
DEL=$(curl -s -X POST "$BASE_BE/api/students/delete/9001")
echo "$DEL" | grep -q "Deleted student 9001" \
  && ok "POST /api/students/delete/{id} hoat dong" || bad "Delete: $(echo "$DEL" | head -c 200)"

# --- 10. Sau xoa, GET khong con tra ve gi nua ---
#   (@RestController tra body rỗng cho null, co the la "" hoac "null")
BODY=$(curl -s "$BASE_BE/api/students/9001")
if [ -z "$BODY" ] || [ "$BODY" = "null" ]; then
  ok "Sau xoa, GET khong con tra ve sinh vien"
else
  bad "Sau xoa con lai: $(echo "$BODY" | head -c 200)"
fi

echo "=== Ket qua: $PASS dat, $FAIL hong ==="
[ "$FAIL" = "0" ] || exit 1
