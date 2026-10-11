#!/usr/bin/env bash
# Smoke test cho Student Manager — dung trong stage TEST (truoc push) va stage kiem tra sau deploy.
#
# Chay (tu container Jenkins hoac tu may dev):
#   BASE_URL=http://localhost:13000 bash scripts/smoke-test.sh
#   bash scripts/smoke-test.sh http://localhost:3000
#
# Khong in/ghi bat ky secret nao. Chi in ket qua JSON da rut gon.
set -u

BASE_URL="${1:-${BASE_URL:-http://localhost:3000}}"
API="$BASE_URL/api/students"
TMP_ID=901          # sinh vien tam de test POST/DELETE — id rac de tranh cham du lieu mau
PASS=0
FAIL=0

ok()  { echo "  PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Che do: test image co san -> $API ==="

# Cho backend len (Spring Boot + SQL Server can thoi gian) — toi da ~180s
ready=0
for i in $(seq 1 60); do
    c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$API" 2>/dev/null || echo 000)
    if [ "$c" = "200" ]; then ready=1; echo "App san sang sau $((i * 3))s"; break; fi
    sleep 3
done
if [ "$ready" != "1" ]; then
    echo "=== Ket qua: 0 dat, 8 huong (app khong len duoc) ==="
    exit 1
fi

# Dọn sinh vien tam cua lan chay truoc that bai (neu co)
curl -s --max-time 10 -X POST "$API/delete/$TMP_ID" >/dev/null 2>&1 || true

BASE_COUNT=$(curl -s --max-time 10 "$API" | grep -o '"id"' | wc -l | tr -d ' ')

# 1. Frontend tra ve trang chu
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$BASE_URL/")
[ "$c" = "200" ] && ok "frontend GET / -> 200" || bad "frontend GET / -> $c (ky vong 200)"

# 2. REST API tra ve danh sach
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$API")
[ "$c" = "200" ] && ok "GET /api/students -> 200" || bad "GET /api/students -> $c (ky vong 200)"

# 3. Co du lieu mau trong DB (entrypoint tao 3 ban ghi)
[ "$BASE_COUNT" -ge 1 ] && ok "DB co du lieu mau ($BASE_COUNT ban ghi)" \
                        || bad "DB rong — entrypoint khong seed duoc"

# 4. Lay sinh vien theo id=1
c=$(curl -s --max-time 10 "$API/1" | grep -c '"name"')
[ "$c" -ge 1 ] && ok "GET /api/students/1 co truong name" || bad "GET /api/students/1 thieu truong name"

# 5. Tim kiem theo ten
n=$(curl -s --max-time 10 "$API/search?name=a" | grep -o '"id"' | wc -l | tr -d ' ')
[ "$n" -ge 1 ] && ok "GET /api/students/search?name=a co $n ket qua" || bad "search?name=a khong tra ket qua"

# 6. Them sinh vien tam
c=$(curl -s --max-time 10 -o /tmp/add.json -w '%{http_code}' -X POST \
      -H 'Content-Type: application/json' \
      -d "{\"id\":$TMP_ID,\"name\":\"Smoke Test\",\"age\":20,\"email\":\"smoke@test.local\"}" \
      "$API")
if [ "$c" = "200" ] && grep -q "\"id\":$TMP_ID" /tmp/add.json; then
    ok "POST /api/students them duoc id=$TMP_ID"
else
    bad "POST /api/students -> $c (khong tra ve id=$TMP_ID)"
fi

# 7. Danh sach tang 1 ban ghi sau khi them
NEW_COUNT=$(curl -s --max-time 10 "$API" | grep -o '"id"' | wc -l | tr -d ' ')
if [ "$NEW_COUNT" = "$((BASE_COUNT + 1))" ]; then
    ok "danh sach tang 1 ban ghi ($BASE_COUNT -> $NEW_COUNT)"
else
    bad "danh sach khong tang ($BASE_COUNT -> $NEW_COUNT)"
fi

# 8. Xoa sinh vien tam, tra lai trang thai ban dau
c=$(curl -s --max-time 10 -X POST "$API/delete/$TMP_ID" | grep -c "Deleted student $TMP_ID")
END_COUNT=$(curl -s --max-time 10 "$API" | grep -o '"id"' | wc -l | tr -d ' ')
if [ "$c" -ge 1 ] && [ "$END_COUNT" = "$BASE_COUNT" ]; then
    ok "POST /delete/$TMP_ID xoa duoc, DB quay lai $END_COUNT ban ghi"
else
    bad "delete id=$TMP_ID that bai (sau xoa con $END_COUNT ban ghi)"
fi

rm -f /tmp/add.json
echo "=== Ket qua: $PASS dat, $FAIL huong ==="
[ "$FAIL" = "0" ] || exit 1
exit 0
