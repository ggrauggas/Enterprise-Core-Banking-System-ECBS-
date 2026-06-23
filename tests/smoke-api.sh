#!/usr/bin/env bash
# End-to-end smoke / integration test for the ECBS stack (Fase 14).
#
# Drives the full chain frontend-less: backend REST API -> COBOL bridge
# -> COBOL programs -> PostgreSQL. Run it against a stack started with
# `docker compose up -d` (locally or in CI):
#
#   BASE_URL=http://localhost:8080 tests/smoke-api.sh
#
# Exits non-zero on the first failed assertion.
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
API="$BASE_URL/api/v1"
PASS=0
FAIL=0

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

# assert_status METHOD PATH EXPECTED [JSON_BODY]
assert_status() {
    method="$1"; path="$2"; expected="$3"; body="${4:-}"
    if [ -n "$body" ]; then
        code=$(curl -s -o /tmp/ecbs_resp -w '%{http_code}' -X "$method" \
            -H 'Content-Type: application/json' -H 'X-ECBS-User: smoke' \
            -d "$body" "$API$path")
    else
        code=$(curl -s -o /tmp/ecbs_resp -w '%{http_code}' -X "$method" \
            -H 'X-ECBS-User: smoke' "$API$path")
    fi
    if [ "$code" = "$expected" ]; then
        green "PASS $method $path -> $code"
        PASS=$((PASS + 1))
    else
        red "FAIL $method $path -> $code (expected $expected)"
        cat /tmp/ecbs_resp; echo
        FAIL=$((FAIL + 1))
    fi
}

wait_for_backend() {
    echo "Waiting for backend at $BASE_URL ..."
    for _ in $(seq 1 60); do
        if curl -sf "$BASE_URL/actuator/health" >/dev/null 2>&1; then
            green "Backend is up."
            return 0
        fi
        sleep 3
    done
    red "Backend did not become healthy in time."
    exit 1
}

json_field() { # FIELD  (reads /tmp/ecbs_resp)
    python3 -c "import json,sys; print(json.load(open('/tmp/ecbs_resp'))['$1'])"
}

wait_for_backend

echo "== System / health =="
assert_status GET /system/info 200
assert_status GET /system/model-stats 200

echo "== Customer lifecycle =="
# Unique identity per run so the suite is idempotent against a non-empty
# database (the COBOL layer enforces email uniqueness -> E003).
RUN_ID=$(date +%s)
EMAIL="smoke.${RUN_ID}@ecbs.com"
PHONE="+346${RUN_ID}"
CUST_BODY="{\"firstName\":\"Smoke\",\"lastName\":\"Tester\",\"birthDate\":\"1990-05-05\",\"email\":\"$EMAIL\",\"phone\":\"$PHONE\"}"
assert_status POST /customers 201 "$CUST_BODY"
CUST_ID=$(json_field customerId)
echo "Created customer #$CUST_ID ($EMAIL)"
assert_status GET "/customers/$CUST_ID" 200
assert_status POST /customers 409 "$CUST_BODY"   # duplicate email rejected by COBOL

echo "== Account + deposit =="
assert_status POST /accounts 201 "{\"customerId\":$CUST_ID,\"accountType\":\"CHECKING\"}"
ACC_ID=$(json_field accountId)
echo "Opened account #$ACC_ID"
assert_status POST /transactions/deposits 201 "{\"accountId\":$ACC_ID,\"amount\":250.00,\"description\":\"smoke deposit\"}"
assert_status POST /transactions/withdrawals 422 "{\"accountId\":$ACC_ID,\"amount\":999999.00}"

echo "== Reporting + audit =="
assert_status GET /reports/bank 200
assert_status GET "/audit?entityType=CUSTOMER&entityId=$CUST_ID" 200

echo "== Validation rejections =="
assert_status POST /customers 400 '{"firstName":"","lastName":"X","birthDate":"1990-01-01","email":"x@y.com","phone":"+34600000000"}'
assert_status GET /customers/99999999 404

echo ""
echo "Smoke results: $PASS passed, $FAIL failed."
[ "$FAIL" -eq 0 ] || exit 1
green "All smoke assertions passed."
