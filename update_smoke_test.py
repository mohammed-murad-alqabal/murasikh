content = """#!/bin/bash
set -e

BASE_URL=${1:-"http://localhost:8000"}

echo "Running smoke tests against $BASE_URL..."

# 1. Health check
echo "Testing /health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
if [ "$HEALTH_STATUS" != "200" ]; then
    echo "❌ Health check failed with status $HEALTH_STATUS"
    return 1
fi
echo "✅ Health check passed."

# 2. Auth test (attempt to get a 401 or 422 to verify route exists)
echo "Testing /api/v1/auth endpoint..."
AUTH_STATUS=$(curl -s -X POST -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/auth/login" -H "Content-Type: application/x-www-form-urlencoded" -d "username=test&password=test")
if [ "$AUTH_STATUS" != "401" ] && [ "$AUTH_STATUS" != "422" ] && [ "$AUTH_STATUS" != "200" ] && [ "$AUTH_STATUS" != "400" ]; then
    echo "❌ Auth endpoint returned unexpected status $AUTH_STATUS (expected 401/400/422/200)"
    return 1
fi
echo "✅ Auth endpoint passed."

# 3. Recommend test
echo "Testing /api/v1/analyze/recommend endpoint..."
RECOMMEND_STATUS=$(curl -s -X POST -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/analyze/recommend" -H "Content-Type: application/json" -d '{"text": "test"}')
if [ "$RECOMMEND_STATUS" != "401" ] && [ "$RECOMMEND_STATUS" != "422" ] && [ "$RECOMMEND_STATUS" != "200" ] && [ "$RECOMMEND_STATUS" != "403" ]; then
    echo "❌ Recommend endpoint returned unexpected status $RECOMMEND_STATUS"
    return 1
fi
echo "✅ Recommend endpoint passed."

echo "🎉 All smoke tests completed successfully!"
"""

with open("scripts/smoke_test.sh", "w") as f:
    f.write(content)
