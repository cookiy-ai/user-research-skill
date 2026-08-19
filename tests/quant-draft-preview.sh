#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

printf '%s' 'test-token' > "$test_dir/token.txt"
export QUANT_DRAFT_REQUEST_LOG="$test_dir/requests.ndjson"

curl() {
  local payload='' body
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == '-d' ]]; then
      payload="$2"
      shift 2
      continue
    fi
    shift
  done
  printf '%s\n' "$payload" >> "$QUANT_DRAFT_REQUEST_LOG"

  case "$payload" in
    *'"method":"initialize"'*)
      body='{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-03-26","capabilities":{},"serverInfo":{"name":"test","version":"1"}}}'
      ;;
    *'"method":"notifications/initialized"'*)
      body='{"jsonrpc":"2.0","result":{}}'
      ;;
    *'"name":"cookiy_quant_survey_admin_link"'*)
      # Shape captured from a running backend: adminLink returns the URL and
      # its TTL, and no survey_id. An earlier fixture invented one.
      body='{"jsonrpc":"2.0","id":2,"result":{"content":[],"isError":false,"structuredContent":{"ok":true,"data":{"admin_login_url":"https://ls.test/index.php?cookiyBridge=loginAs&token=abc","token_ttl_seconds":120},"error":null}}}'
      ;;
    *)
      body='{"jsonrpc":"2.0","id":0,"error":{"message":"unexpected test request"}}'
      ;;
  esac

  printf '%s\n200' "$body"
}
export -f curl

output="$(
  COOKIY_CREDENTIALS="$test_dir/token.txt" \
  bash "$repo_root/references/cookiy/scripts/cookiy.sh" \
    quant admin-link --survey-id 191329
)"

printf '%s' "$output" | jq -e '
  .admin_login_url == "https://ls.test/index.php?cookiyBridge=loginAs&token=abc"
  and .token_ttl_seconds == 120
' >/dev/null

grep -F '"name":"cookiy_quant_survey_admin_link"' \
  "$QUANT_DRAFT_REQUEST_LOG" >/dev/null

grep -F '"activate": false' \
  "$repo_root/references/cookiy/cookiy-quant.md" >/dev/null
grep -F 'Native activation automatically reruns' \
  "$repo_root/references/cookiy/cookiy-quant.md" >/dev/null

echo 'CLI quant draft-preview lifecycle test passed.'
