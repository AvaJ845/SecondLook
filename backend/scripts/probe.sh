#!/usr/bin/env bash
# Probe whether a model id actually serves, through the deployed worker.
#   ./scripts/probe.sh 'nvidia:nvidia/nemotron-3.5-lightning-30b-a3b'
#   ./scripts/probe.sh                      # no arg → runs the current chains' models
#
# Needs BASE_URL + CLIENT_TOKEN, or reads them from ../Config/AIConfig.plist.
set -euo pipefail

BASE_URL="${BASE_URL:-}"
CLIENT_TOKEN="${CLIENT_TOKEN:-}"
plist="$(dirname "$0")/../../Config/AIConfig.plist"
if [[ -z "$BASE_URL" && -f "$plist" ]]; then
  BASE_URL=$(/usr/libexec/PlistBuddy -c "Print :BaseURL" "$plist" 2>/dev/null || true)
  CLIENT_TOKEN=$(/usr/libexec/PlistBuddy -c "Print :ClientToken" "$plist" 2>/dev/null || true)
fi
[[ -n "$BASE_URL" && -n "$CLIENT_TOKEN" ]] || { echo "set BASE_URL and CLIENT_TOKEN" >&2; exit 1; }

probe() {
  local m="$1" body
  body=$(curl -sS -m 35 -w '\n%{http_code} %{time_total}s' \
    -H "Authorization: Bearer $CLIENT_TOKEN" -H "Content-Type: application/json" \
    "$BASE_URL/v1/generate?only=$m" \
    -d '{"task":"plainSummary","tier":"fast","input":{"signals":"upfront_payment"},"prompt":"one short sentence"}') || true
  printf '%s\n  %s\n\n' "$(tail -1 <<<"$body")  $m" "$(head -c 160 <<<"$body")"
}

if [[ $# -ge 1 ]]; then
  probe "$1"
else
  for m in \
    "openrouter:minimax/minimax-m2.7:free" \
    "nvidia:nvidia/nemotron-3.5-lightning-30b-a3b" \
    "openrouter:z-ai/glm-5.2:free" \
    "openrouter:minimax/minimax-m3:free" \
    "openrouter:google/gemma-4-31b-it:free"; do
    probe "$m"
    sleep 8   # stay under the bootstrap-token rate limit
  done
fi
