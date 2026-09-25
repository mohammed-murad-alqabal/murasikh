#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8000}"

request_status() {
  curl --silent --show-error --connect-timeout 5 --max-time 15 \
    -o /dev/null -w '%{http_code}' "$@"
}

expect_status() {
  local name="$1"
  local expected="$2"
  shift 2
  local status
  status="$(request_status "$@")"
  if [[ "$status" != "$expected" ]]; then
    echo "FAIL: $name expected HTTP $expected, got HTTP $status" >&2
    exit 1
  fi
  echo "PASS: $name (HTTP $status)"
}

echo "Running Murasikh smoke tests against $BASE_URL"

expect_status "liveness" 200 "$BASE_URL/health/live"
expect_status "readiness" 200 "$BASE_URL/health/ready"
expect_status "login validation" 422 \
  -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data ''
expect_status "register validation" 422 \
  -X POST "$BASE_URL/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{}'
expect_status "analyze route and validation" 422 \
  -X POST "$BASE_URL/api/v1/analyze" \
  -H "Content-Type: application/json" \
  -d '{}'

printf '%s\n' 'All smoke tests passed.'
