#!/usr/bin/env bash
# Smoke tests for the canonical Murasikh API contract.

set -euo pipefail

BASE_URL="${1:-https://api.murassikh.com}"
PASS=0
FAIL=0

request_status() {
    curl --silent --show-error --connect-timeout 10 --max-time 20 \
        -o /dev/null -w "%{http_code}" "$@"
}

print_result() {
    local name="$1"
    local status="$2"
    local expected="$3"
    if [[ "$status" == "$expected" ]]; then
        echo "  PASS: $name (HTTP $status)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected HTTP $expected, got HTTP $status)" >&2
        FAIL=$((FAIL + 1))
    fi
}

echo "======================================"
echo " Murasikh Staging Smoke Test"
echo " Target: $BASE_URL"
echo "======================================"

echo "--- Health Checks ---"
print_result "/health/live" "$(request_status "$BASE_URL/health/live")" 200
print_result "/health/ready" "$(request_status "$BASE_URL/health/ready")" 200

# Malformed bodies validate that the canonical routes are registered without
# invoking the AI/database recommendation path.
echo "--- Contract Validation ---"
print_result "POST /auth/login" "$(request_status \
    -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data '')" 422
print_result "POST /auth/register" "$(request_status \
    -X POST "$BASE_URL/api/v1/auth/register" \
    -H "Content-Type: application/json" \
    -d '{}')" 422
print_result "POST /analyze" "$(request_status \
    -X POST "$BASE_URL/api/v1/analyze" \
    -H "Content-Type: application/json" \
    -d '{}')" 422

printf '%s\n' "======================================"
printf ' Results: %s passed, %s failed\n' "$PASS" "$FAIL"
printf '%s\n' "======================================"

if (( FAIL > 0 )); then
    exit 1
fi
