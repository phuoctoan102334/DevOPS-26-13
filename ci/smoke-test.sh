#!/usr/bin/env bash
# ===================================================================
# Smoke test cho DevOPS-26-13 (Student Management System)
# 8 kiem tra nhanh, chay truc tiep tren may host da deploy stack.
#   ./ci/smoke-test.sh          -> tra ve 1 neu co kiem tra that bai
# ===================================================================
set -u

BACKEND_PORT="${BACKEND_PORT:-8080}"
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
PROJECT="${COMPOSE_PROJECT:-student-management-system}"

pass=0
fail=0

ok() { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
ng() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# Lay ma HTTP; loi mang -> 000
code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1" 2>/dev/null || printf '000'
}

echo "== SMOKE TEST: 8 kiem tra =="

# 1. Trang chu frontend
c=$(code "http://localhost:${FRONTEND_PORT}/")
if [ "$c" = "200" ]; then ok "GET / (frontend nginx) = 200"; else ng "GET / (frontend nginx) = $c"; fi

# 2. API di qua nginx proxy cua frontend
c=$(code "http://localhost:${FRONTEND_PORT}/api/students")
if [ "$c" = "200" ]; then ok "GET /api/students qua proxy :${FRONTEND_PORT} = 200"; else ng "GET /api/students qua proxy = $c"; fi

# 3. API truc tiep backend
c=$(code "http://localhost:${BACKEND_PORT}/api/students")
if [ "$c" = "200" ]; then ok "GET /api/students truc tiep :${BACKEND_PORT} = 200"; else ng "GET /api/students truc tiep = $c"; fi

# 4. Lay 1 sinh vien theo id
c=$(code "http://localhost:${BACKEND_PORT}/api/students/1")
if [ "$c" = "200" ]; then ok "GET /api/students/1 = 200"; else ng "GET /api/students/1 = $c"; fi

# 5. Tim kiem theo ten
c=$(code "http://localhost:${BACKEND_PORT}/api/students/search?name=A")
if [ "$c" = "200" ]; then ok "GET /api/students/search?name=A = 200"; else ng "GET /api/students/search = $c"; fi

# 6. Du lieu seed trong database
body="$(curl -s --max-time 5 "http://localhost:${BACKEND_PORT}/api/students" 2>/dev/null || true)"
if printf '%s' "$body" | grep -q '"name"'; then ok "Du lieu sinh vien da duoc seed"; else ng "Khong doc duoc du lieu seed"; fi

# 7. Container database khoe man
st="$(docker inspect -f '{{.State.Health.Status}}' "${PROJECT}-database-1" 2>/dev/null || echo missing)"
if [ "$st" = "healthy" ]; then ok "database container = healthy"; else ng "database container = $st"; fi

# 8. Container frontend dang chay
st="$(docker inspect -f '{{.State.Status}}' "${PROJECT}-frontend-1" 2>/dev/null || echo missing)"
if [ "$st" = "running" ]; then ok "frontend container = running"; else ng "frontend container = $st"; fi

echo "----------------------------------------"
printf 'KET QUA: %s PASS / %s FAIL (8 kiem tra)\n' "$pass" "$fail"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
