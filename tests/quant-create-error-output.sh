#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

printf '%s' 'test-token' > "$test_dir/token.txt"

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

  case "$payload" in
    *'"method":"initialize"'*)
      body='{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-03-26","capabilities":{},"serverInfo":{"name":"test","version":"1"}}}'
      ;;
    *'"method":"notifications/initialized"'*)
      body='{"jsonrpc":"2.0","result":{}}'
      ;;
    *'"method":"tools/call"'*)
      body='{"jsonrpc":"2.0","id":2,"result":{"content":[],"isError":true,"structuredContent":{"ok":false,"data":null,"error":{"code":"QUANT_SURVEY_LOGIC_INVALID","message":"The questionnaire contains invalid survey logic and remains inactive. Correct the reported expressions before retrying.","details":{"survey_id":191329,"engine":"LimeSurvey ExpressionScript","error_count":1,"errors":[{"language":"es","scope":"group","code":"native_logic_error","count":1,"group_id":1207,"issues":[{"code":"undefined_function","message":"Undefined function","token":"S4.NAOK.contains","expression":"S1 == '\''Y'\'' and !S4.NAOK.contains('\''A5'\'')"}]}]}}}}}'
      ;;
    *)
      body='{"jsonrpc":"2.0","id":0,"error":{"message":"unexpected test request"}}'
      ;;
  esac

  printf '%s\n200' "$body"
}
export -f curl

set +e
output="$(
  COOKIY_CREDENTIALS="$test_dir/token.txt" \
  bash "$repo_root/references/cookiy/scripts/cookiy.sh" \
    quant create --json '{"survey_title":"Broken relevance","groups":[]}'
)"
status=$?
set -e

if [[ $status -eq 0 ]]; then
  echo 'Expected quant create to exit non-zero for a tool error.' >&2
  exit 1
fi

printf '%s' "$output" | jq -e '
  .ok == false
  and .error.code == "QUANT_SURVEY_LOGIC_INVALID"
  and .error.details.errors[0].group_id == 1207
  and .error.details.errors[0].issues[0].message == "Undefined function"
  and .error.details.errors[0].issues[0].token == "S4.NAOK.contains"
  and .error.details.errors[0].issues[0].expression
      == "S1 == '\''Y'\'' and !S4.NAOK.contains('\''A5'\'')"
' >/dev/null

grep -F 'Report every item in' \
  "$repo_root/references/cookiy/cookiy-quant.md" >/dev/null

echo 'CLI quant-create structured error passthrough test passed.'
