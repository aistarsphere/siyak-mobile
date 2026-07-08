#!/usr/bin/env bash
# Optional manual smoke test against a LIVE backend (not used by unit tests).
#
# Usage:
#   ./tool/live_smoke.sh                          # documented public URL
#   ./tool/live_smoke.sh http://127.0.0.1:8000    # local backend
set -euo pipefail

BASE="${1:-https://v4nbg9o9snrk.shares.zrok.io}"
echo "Smoke-testing backend: $BASE"
jqbin=$(command -v jq || echo "python3 -m json.tool")

step() { echo; echo "== $1"; }

step "GET /api/modes?lang=ar (health + Arabic catalogue)"
curl -sf "$BASE/api/modes?lang=ar" | $jqbin | head -20

step "GET /api/modes?lang=en (English catalogue)"
curl -sf "$BASE/api/modes?lang=en" | $jqbin | head -10

step "GET /api/new?mode=general&difficulty=easy (new Arabic game)"
NEW=$(curl -sf "$BASE/api/new?mode=general&difficulty=easy")
echo "$NEW"
GID=$(echo "$NEW" | python3 -c "import json,sys; print(json.load(sys.stdin)['gameId'])")

step "POST /api/guess (valid Arabic word)"
curl -sf -X POST "$BASE/api/guess" -H 'Content-Type: application/json' \
  -d "{\"word\": \"بيت\", \"mode\": \"general\", \"difficulty\": \"easy\", \"gameId\": $GID}"
echo

step "POST /api/guess (invalid word → expect 400 detail)"
curl -s -X POST "$BASE/api/guess" -H 'Content-Type: application/json' \
  -d "{\"word\": \"xyz123\", \"mode\": \"general\", \"difficulty\": \"easy\", \"gameId\": $GID}"
echo

step "GET /api/hint (level 1)"
curl -sf "$BASE/api/hint?mode=general&difficulty=easy&gameId=$GID&level=1"
echo

step "GET /api/datastore/words?q=سيا (autocomplete)"
curl -sf "$BASE/api/datastore/words?q=%D8%B3%D9%8A%D8%A7&lang=ar&limit=5"
echo

echo
echo "Smoke test passed ✔"
