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
      body='{"jsonrpc":"2.0","id":2,"result":{"content":[],"isError":true,"structuredContent":{"ok":false,"data":null,"error":{"code":"QUANT_SURVEY_LOGIC_INVALID","message":"The questionnaire contains invalid survey logic. The temporary draft was deleted; correct the reported expressions before retrying.","details":{"rolled_back":true,"discarded_survey_id":191329,"engine":"LimeSurvey ExpressionScript","error_count":2,"errors":[{"language":"es","scope":"group","code":"native_logic_error","count":1,"group_id":1207,"group_index":1,"group_title":"Main","issues":[{"code":"undefined_function","message":"Undefined function","token":"S4.NAOK.contains","expression":"S1 == '\''Y'\'' and !S4.NAOK.contains('\''A5'\'')"}]},{"language":"es","scope":"survey","code":"native_logic_error","count":1,"location":"End URL","issues":[{"code":"native_expression_error","message":"Undefined variable","token":"MISSING","expression":"{MISSING}"}]}]}}}}}'
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
  and .error.details.rolled_back == true
  and .error.details.discarded_survey_id == 191329
  and (.error.details.errors | length) == 2
' >/dev/null

# The fields that let the user find the problem in the JSON they sent. The
# survey was deleted before this error was returned, so group_id/question_id
# point at nothing; these are the ones that must survive to stdout.
printf '%s' "$output" | jq -e '
  .error.details.errors[0].group_index == 1
  and .error.details.errors[0].group_title == "Main"
  and .error.details.errors[0].language == "es"
  and .error.details.errors[0].issues[0].message == "Undefined function"
  and .error.details.errors[0].issues[0].token == "S4.NAOK.contains"
  and .error.details.errors[0].issues[0].expression
      == "S1 == '\''Y'\'' and !S4.NAOK.contains('\''A5'\'')"
' >/dev/null

# A survey-level error has no group or question to point at; `location` is the
# only thing naming the broken field, so losing it makes the error unactionable.
printf '%s' "$output" | jq -e '
  .error.details.errors[1].scope == "survey"
  and .error.details.errors[1].location == "End URL"
  and (.error.details.errors[1] | has("group_index")) == false
  and .error.details.errors[1].issues[0].token == "MISSING"
' >/dev/null

# The skill instructions must name the fields the agent should report, or the
# diagnostics reach the CLI and then get described uselessly.
for field in group_index group_title question_code location; do
  grep -F "\`$field\`" \
    "$repo_root/references/cookiy/cookiy-quant.md" >/dev/null \
    || { echo "cookiy-quant.md does not tell the agent to report $field" >&2; exit 1; }
done
grep -F 'audit context only' \
  "$repo_root/references/cookiy/cookiy-quant.md" >/dev/null

echo 'CLI quant-create structured error passthrough test passed.'
