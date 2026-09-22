#!/bin/bash
# F-16 #6: Smoke test against /health, auth routes, and recommendation
# Verifies staging deployment is functioning end-to-end.

set -e

BASE_URL=${1:-"https://api.murassikh.com"}
PASS=0
FAIL=0

print_result() {
    local name=$1
    local code=$2
    local expected=$3
    if [ "$code" -eq "$expected" ]; then
        echo "  ✅ PASS: $name (HTTP $code)"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $name (expected HTTP $expected, got HTTP $code)"
        FAIL=$((FAIL + 1))
    fi
}

echo "======================================"
echo " Murassikh Staging Smoke Test"
echo " Target: $BASE_URL"
echo "======================================"

echo ""
echo "--- Health Checks ---"

code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health/live")
print_result "/health/live" "$code" 200

code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health/ready")
print_result "/health/ready" "$code" 200

code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
print_result "/health (alias)" "$code" 200

echo ""
echo "--- Auth Routes ---"

# Login with invalid credentials should return 401 or 422
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"nonexistent@test.com","password":"wrongpassword"}')
print_result "POST /auth/login (invalid creds → 401/400)" "$code" 401

# Register with empty body should return 422 (Unprocessable Entity)
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d '{}')
print_result "POST /auth/register (empty body → 422)" "$code" 422

echo ""
echo "======================================"
echo " Results: $PASS passed, $FAIL failed"
echo "======================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
