#!/usr/bin/env bash
# Cookiy CLI — pure shell wrapper over hosted JSON-RPC using curl.
# No dependencies beyond bash, curl, grep, sed, awk.
set -euo pipefail

VERSION="1.9.1"
DEFAULT_SERVER_URL="https://s-api.cookiy.ai"
DEFAULT_CREDENTIALS_PATH="${COOKIY_CREDENTIALS:-$HOME/.mcp/cookiy/credentials.json}"
TIMEOUT=120
RPC_ID=0

# --- helpers ---------------------------------------------------------------

die() { echo "$1" >&2; exit "${2:-1}"; }

next_id() { RPC_ID=$((RPC_ID + 1)); echo "$RPC_ID"; }

# Extract a top-level string value from a flat JSON file/string.
# Usage: json_get <key> < file_or_string
# Handles: "key": "value" and "key":"value"
json_get() {
  sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# JSON-escape a string (handles quotes, backslashes, newlines)
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | tr '\n' ' '
}

# Read a key from credentials file
cred_val() {
  json_get "$1" < "$CREDENTIALS_PATH"
}

resolve_alias() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    prod|production) echo "https://s-api.cookiy.ai" ;;
    dev)             echo "https://dev-api.cookiy.ai" ;;
    dev2)            echo "https://dev2-api.cookiy.ai" ;;
    dev3)            echo "https://dev3-api.cookiy.ai" ;;
    preview)         echo "https://preview-api.cookiy.ai" ;;
    staging)         echo "https://staging-api.cookiy.ai" ;;
    test)            echo "https://test-api.cookiy.ai" ;;
    *)               echo "$1" ;;
  esac
}

usage() {
  cat <<EOF
Cookiy CLI v${VERSION}  (shell)

Usage:
  cookiy.sh [--server-url <url>] [--credentials <path>] [--mcp-url <url>] <command> ...

Global options:
  --server-url     Override Cookiy API base URL
  --mcp-url        Full JSON-RPC URL (overrides COOKIY_MCP_URL and credentials mcp_url)
  --credentials    Path to credentials.json (default: ~/.mcp/cookiy/credentials.json)

Environment:
  COOKIY_CREDENTIALS   Path to credentials.json
  COOKIY_SERVER_URL    API base when not in file
  COOKIY_MCP_URL       Full MCP URL (e.g. https://s-api.cookiy.ai/mcp)

Commands:
  doctor                      Connectivity check
  help <topic>                Workflow help
  study list|create|get|progress|activity|show|guide ...
  interview list|playback|simulate ...
  recruit start|status
  report status|share-link
  quant list|create|detail|patch|report|results|stats
  billing balance|checkout
  tool call <operation>       Escape hatch: --json '<arguments-object>'

Examples:
  cookiy.sh doctor
  cookiy.sh study list --limit 10
  cookiy.sh study create --query "..." --language zh
  cookiy.sh tool call cookiy_study_get --json '{"study_id":"..."}'
EOF
}

# --- credentials & URL resolution ------------------------------------------

CREDENTIALS_PATH="$DEFAULT_CREDENTIALS_PATH"
SERVER_URL_OPT=""
MCP_URL_OPT=""
ACCESS_TOKEN=""
MCP_ENDPOINT=""

load_credentials() {
  [[ -f "$CREDENTIALS_PATH" ]] || die "Missing credentials at $CREDENTIALS_PATH. Run npx cookiy-mcp to authenticate."
  ACCESS_TOKEN="$(cred_val access_token)"
  [[ -n "$ACCESS_TOKEN" ]] || die "No access_token in $CREDENTIALS_PATH"
}

resolve_mcp_endpoint() {
  if [[ -n "$MCP_URL_OPT" ]]; then MCP_ENDPOINT="$MCP_URL_OPT"; return; fi
  if [[ -n "${COOKIY_MCP_URL:-}" ]]; then MCP_ENDPOINT="$COOKIY_MCP_URL"; return; fi
  local cred_mcp; cred_mcp="$(cred_val mcp_url)"
  if [[ -n "$cred_mcp" ]]; then MCP_ENDPOINT="$cred_mcp"; return; fi
  local base="${SERVER_URL_OPT:-${COOKIY_SERVER_URL:-}}"
  if [[ -z "$base" ]]; then base="$(cred_val server_url)"; fi
  base="${base:-$DEFAULT_SERVER_URL}"
  MCP_ENDPOINT="${base%/}/mcp"
}

# --- JSON-RPC over curl ----------------------------------------------------

post_jsonrpc() {
  curl -sf --max-time "$TIMEOUT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$1" \
    "$MCP_ENDPOINT"
}

# Check if a JSON-RPC response has an error. Prints error message to stderr and returns 1 if so.
check_rpc_error() {
  local resp="$1"
  # Look for "error":{"message":"..."}
  local err_msg
  err_msg="$(echo "$resp" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*{[^}]*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  if [[ -n "$err_msg" ]]; then
    echo "$err_msg" >&2
    return 1
  fi
  return 0
}

# Extract .result (or .result.structuredContent) and pretty-print with awk
extract_result() {
  cat  # pass through raw JSON — pipe to jq externally if you want formatting
}

# invoke <tool_name> <arguments_json>
# Performs the 3-step MCP handshake: initialize, notify, tools/call
invoke() {
  local tool_name="$1"
  local args_json="${2:-\{\}}"

  # 1) initialize
  local init_resp
  init_resp="$(post_jsonrpc "{\"jsonrpc\":\"2.0\",\"id\":$(next_id),\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"cookiy-cli-sh\",\"version\":\"1.0.0\"}}}")" \
    || die "MCP initialize request failed"
  check_rpc_error "$init_resp" || die "MCP initialize error"

  # 2) notifications/initialized
  post_jsonrpc '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null 2>&1 || true

  # 3) tools/call
  local call_resp
  call_resp="$(post_jsonrpc "{\"jsonrpc\":\"2.0\",\"id\":$(next_id),\"method\":\"tools/call\",\"params\":{\"name\":\"${tool_name}\",\"arguments\":${args_json}}}")" \
    || die "MCP tools/call request failed"
  check_rpc_error "$call_resp" || exit 1

  echo "$call_resp" | extract_result
}

# --- arg builder -----------------------------------------------------------
# Parses --key value pairs from "$@" and builds a JSON object.
# Only includes keys listed in the allowed-keys spec.
# Usage: build_json "key1 key2 key3" "$@"
# Numeric keys: limit, amount_usd_cents, persona_count, target_participants, max_price_per_interview
# Boolean keys: include_debug, auto_launch, force_reconfigure, wait, auto_generate_personas, recruit_reconfigure_confirmed
# The rest are strings.
# Sets global: BUILT_JSON, ARG_WAIT, ARG_JSON_RAW, ARG_POSITIONALS

ARG_WAIT=""
ARG_JSON_RAW=""
ARG_POSITIONALS=""

build_json() {
  local allowed="$1"; shift
  local -a pos=()
  local json="{"
  local first=true
  ARG_WAIT=""
  ARG_JSON_RAW=""
  ARG_POSITIONALS=""

  while [[ $# -gt 0 ]]; do
    if [[ "$1" == --* ]]; then
      local key="${1#--}"
      key="${key//-/_}"
      if [[ $# -gt 1 && "${2:0:2}" != "--" ]]; then
        local val="$2"; shift 2
      else
        local val="true"; shift
      fi
      # Special: --wait and --json are never part of the tool args
      if [[ "$key" == "wait" ]]; then ARG_WAIT="$val"; continue; fi
      if [[ "$key" == "json" ]]; then ARG_JSON_RAW="$val"; continue; fi
      # Skip if not in allowed list
      case " $allowed " in
        *" $key "*) ;;
        *) continue ;;
      esac
      $first || json+=","
      first=false
      # Numeric
      case "$key" in
        limit|amount_usd_cents|persona_count|target_participants|max_price_per_interview)
          json+="\"$key\":$val" ;;
        include_debug|auto_launch|force_reconfigure|auto_generate_personas|recruit_reconfigure_confirmed)
          json+="\"$key\":$val" ;;
        *)
          json+="\"$key\":\"$(json_escape "$val")\"" ;;
      esac
    else
      pos+=("$1"); shift
    fi
  done
  json+="}"
  BUILT_JSON="$json"
  ARG_POSITIONALS="${pos[*]+"${pos[*]}"}"
}

# Merge ARG_JSON_RAW into BUILT_JSON (shallow merge via string manipulation)
# This is a best-effort merge for flat objects.
merge_raw_json() {
  if [[ -z "$ARG_JSON_RAW" || "$ARG_JSON_RAW" == "{}" ]]; then return; fi
  local base="$BUILT_JSON"
  local extra="$ARG_JSON_RAW"
  # Strip outer braces
  base="${base#\{}"
  base="${base%\}}"
  extra="${extra#\{}"
  extra="${extra%\}}"
  if [[ -z "$base" ]]; then
    BUILT_JSON="{$extra}"
  elif [[ -z "$extra" ]]; then
    BUILT_JSON="{$base}"
  else
    BUILT_JSON="{$base,$extra}"
  fi
}

# Require a key exists in BUILT_JSON (simple check)
require_key() {
  local key="$1"
  local msg="$2"
  if ! echo "$BUILT_JSON" | grep -q "\"$key\""; then
    die "$msg"
  fi
}

# Get a string value from BUILT_JSON
built_get() {
  echo "$BUILT_JSON" | json_get "$1"
}

# --- poll helpers ----------------------------------------------------------

poll_activity() {
  local study_id="$1"
  local interval="${2:-2}"
  local max_rounds="${3:-45}"
  local prev=""
  for ((i=0; i<max_rounds; i++)); do
    local r
    r="$(invoke cookiy_activity_get "{\"study_id\":\"$study_id\"}")"
    echo "$r"
    if ((i > 2)) && [[ "$r" == "$prev" ]]; then return; fi
    if ((i > 1)) && echo "$r" | grep -qiE 'complete|ready|failed|error|succeeded'; then return; fi
    prev="$r"
    sleep "$interval"
  done
}

poll_sim_status() {
  local study_id="$1"
  local job_id="$2"
  local interval="${3:-2}"
  local max_rounds="${4:-45}"
  local prev=""
  for ((i=0; i<max_rounds; i++)); do
    local r
    r="$(invoke cookiy_simulated_interview_status "{\"study_id\":\"$study_id\",\"job_id\":\"$job_id\"}")"
    echo "$r"
    if ((i > 2)) && [[ "$r" == "$prev" ]]; then return; fi
    if ((i > 1)) && echo "$r" | grep -qiE 'complete|ready|failed|error|succeeded|done'; then return; fi
    prev="$r"
    sleep "$interval"
  done
}

# Extract study_id from a JSON response string
extract_study_id() {
  local r="$1"
  local sid
  sid="$(echo "$r" | json_get study_id)"
  if [[ -z "$sid" ]]; then sid="$(echo "$r" | json_get studyId)"; fi
  if [[ -z "$sid" ]]; then sid="$(echo "$r" | json_get id)"; fi
  echo "$sid"
}

extract_job_id() {
  local r="$1"
  local jid
  jid="$(echo "$r" | json_get job_id)"
  if [[ -z "$jid" ]]; then jid="$(echo "$r" | json_get jobId)"; fi
  echo "$jid"
}

# === Parse global options ==================================================

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --server-url)  SERVER_URL_OPT="$2"; shift 2 ;;
    --mcp-url)     MCP_URL_OPT="$2"; shift 2 ;;
    --credentials) CREDENTIALS_PATH="$2"; shift 2 ;;
    *)             ARGS+=("$1"); shift ;;
  esac
done

[[ ${#ARGS[@]} -gt 0 ]] || { usage; exit 0; }

CMD="${ARGS[0]}"
TAIL=("${ARGS[@]:1}")

case "$CMD" in
  -h|--help) usage; exit 0 ;;
  -v|--version) echo "$VERSION"; exit 0 ;;
esac

# All commands below need credentials
load_credentials
resolve_mcp_endpoint

# === COMMANDS ==============================================================

case "$CMD" in

doctor)
  invoke cookiy_introduce '{}'
  ;;

help)
  topic="${TAIL[*]:-}"
  [[ -n "$topic" ]] || die "Usage: cookiy help <topic>"
  invoke cookiy_help "{\"topic\":\"$(json_escape "$topic")\"}"
  ;;

tool)
  [[ "${TAIL[0]:-}" == "call" && -n "${TAIL[1]:-}" ]] || die "Usage: cookiy tool call <operation> --json '{...}'"
  op="${TAIL[1]}"
  build_json "" "${TAIL[@]:2}"
  invoke "$op" "${ARG_JSON_RAW:-\{\}}"
  ;;

study)
  sub="${TAIL[0]:-}"
  stail=("${TAIL[@]:1}")

  case "$sub" in
    list)
      build_json "query status limit cursor" "${stail[@]+"${stail[@]}"}"
      invoke cookiy_study_list "$BUILT_JSON"
      ;;
    create)
      build_json "query language thinking attachments" "${stail[@]+"${stail[@]}"}"
      require_key query "study create requires --query"
      require_key language "study create requires --language"
      result="$(invoke cookiy_study_create "$BUILT_JSON")"
      echo "$result"
      if [[ "$ARG_WAIT" == "true" ]]; then
        sid="$(extract_study_id "$result")"
        [[ -n "$sid" ]] || die "Could not find study_id for --wait"
        poll_activity "$sid"
      fi
      ;;
    get)
      build_json "study_id" "${stail[@]+"${stail[@]}"}"
      require_key study_id "study get requires --study-id"
      invoke cookiy_study_get "$BUILT_JSON"
      ;;
    progress|activity)
      build_json "study_id job_id include_debug" "${stail[@]+"${stail[@]}"}"
      require_key study_id "study progress requires --study-id"
      invoke cookiy_activity_get "$BUILT_JSON"
      ;;
    show)
      build_json "study_id part job_id include_debug" "${stail[@]+"${stail[@]}"}"
      require_key study_id "study show requires --study-id"
      local_study_id="$(built_get study_id)"
      local_part="$(built_get part)"
      case "${local_part:-both}" in
        both|all|"")
          invoke cookiy_study_get "{\"study_id\":\"$local_study_id\"}"
          build_json "study_id job_id include_debug" "${stail[@]+"${stail[@]}"}"
          invoke cookiy_activity_get "$BUILT_JSON"
          ;;
        record)
          invoke cookiy_study_get "{\"study_id\":\"$local_study_id\"}"
          ;;
        progress)
          build_json "study_id job_id include_debug" "${stail[@]+"${stail[@]}"}"
          invoke cookiy_activity_get "$BUILT_JSON"
          ;;
        *) die "study show: --part record|progress|both" ;;
      esac
      ;;
    guide)
      gcmd="${stail[0]:-}"
      gtail=("${stail[@]:1}")
      case "$gcmd" in
        status)
          build_json "study_id" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide status requires --study-id"
          invoke cookiy_guide_status "$BUILT_JSON"
          ;;
        get)
          build_json "study_id" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide get requires --study-id"
          invoke cookiy_guide_get "$BUILT_JSON"
          ;;
        impact)
          build_json "study_id" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide impact requires --study-id"
          [[ -n "$ARG_JSON_RAW" ]] || die "study guide impact requires --json patch object"
          local_sid="$(built_get study_id)"
          invoke cookiy_guide_impact "{\"study_id\":\"$local_sid\",\"patch\":$ARG_JSON_RAW}"
          ;;
        patch)
          build_json "study_id base_revision idempotency_key change_message recruit_reconfigure_confirmed" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide patch requires --study-id"
          require_key base_revision "study guide patch requires --base-revision"
          require_key idempotency_key "study guide patch requires --idempotency-key"
          [[ -n "$ARG_JSON_RAW" ]] || die "study guide patch requires --json"
          # Inject patch key: strip trailing }, append ,"patch":...}
          BUILT_JSON="${BUILT_JSON%\}},\"patch\":$ARG_JSON_RAW}"
          invoke cookiy_guide_patch "$BUILT_JSON"
          ;;
        upload)
          build_json "study_id image_data image_url content_type" "${gtail[@]+"${gtail[@]}"}"
          require_key content_type "study guide upload requires --content-type"
          invoke cookiy_media_upload "$BUILT_JSON"
          ;;
        *) die "Unknown: study guide ${gcmd:-}" ;;
      esac
      ;;
    *) die "Unknown study subcommand: ${sub:-}" ;;
  esac
  ;;

interview)
  sub="${TAIL[0]:-}"
  itail=("${TAIL[@]:1}")

  case "$sub" in
    list)
      build_json "study_id include_simulation cursor" "${itail[@]+"${itail[@]}"}"
      require_key study_id "interview list requires --study-id"
      invoke cookiy_interview_list "$BUILT_JSON"
      ;;
    playback)
      build_json "study_id interview_id" "${itail[@]+"${itail[@]}"}"
      require_key study_id "interview playback requires --study-id"
      require_key interview_id "interview playback requires --interview-id"
      invoke cookiy_interview_playback_get "$BUILT_JSON"
      ;;
    simulate)
      ssub="${itail[0]:-}"
      srest=("${itail[@]:1}")
      case "$ssub" in
        start)
          build_json "study_id auto_generate_personas persona_count interviewee_persona" "${srest[@]+"${srest[@]}"}"
          merge_raw_json
          require_key study_id "interview simulate start requires --study-id"
          result="$(invoke cookiy_simulated_interview_generate "$BUILT_JSON")"
          echo "$result"
          if [[ "$ARG_WAIT" == "true" ]]; then
            local_sid="$(built_get study_id)"
            job_id="$(extract_job_id "$result")"
            [[ -n "$job_id" ]] || die "Could not find job_id for --wait"
            poll_sim_status "$local_sid" "$job_id"
          fi
          ;;
        status)
          build_json "study_id job_id" "${srest[@]+"${srest[@]}"}"
          require_key study_id "interview simulate status requires --study-id"
          require_key job_id "interview simulate status requires --job-id"
          invoke cookiy_simulated_interview_status "$BUILT_JSON"
          ;;
        *) die "interview simulate start|status" ;;
      esac
      ;;
    *) die "Unknown interview subcommand" ;;
  esac
  ;;

recruit)
  sub="${TAIL[0]:-}"
  rtail=("${TAIL[@]:1}")

  case "$sub" in
    start)
      build_json "study_id confirmation_token plain_text target_participants execution_duration max_price_per_interview channel_name auto_launch force_reconfigure recruit_mode survey_public_url" "${rtail[@]+"${rtail[@]}"}"
      merge_raw_json
      require_key study_id "recruit start requires --study-id"
      invoke cookiy_recruit_create "$BUILT_JSON"
      ;;
    status)
      build_json "study_id" "${rtail[@]+"${rtail[@]}"}"
      require_key study_id "recruit status requires --study-id"
      invoke cookiy_recruit_status "$BUILT_JSON"
      ;;
    *) die "recruit start|status" ;;
  esac
  ;;

report)
  sub="${TAIL[0]:-}"
  rtail=("${TAIL[@]:1}")

  case "$sub" in
    status)
      build_json "study_id" "${rtail[@]+"${rtail[@]}"}"
      require_key study_id "report status requires --study-id"
      invoke cookiy_report_status "$BUILT_JSON"
      ;;
    share-link)
      build_json "study_id" "${rtail[@]+"${rtail[@]}"}"
      require_key study_id "report share-link requires --study-id"
      invoke cookiy_report_share_link_get "$BUILT_JSON"
      ;;
    *) die "report status|share-link" ;;
  esac
  ;;

quant)
  sub="${TAIL[0]:-}"
  qtail=("${TAIL[@]:1}")

  case "$sub" in
    list)    tool=cookiy_quant_survey_list ;;
    create)  tool=cookiy_quant_survey_create ;;
    detail)  tool=cookiy_quant_survey_detail ;;
    patch)   tool=cookiy_quant_survey_patch ;;
    report)  tool=cookiy_quant_survey_report ;;
    results) tool=cookiy_quant_survey_results ;;
    stats)   tool=cookiy_quant_survey_stats ;;
    *)       die "quant list|create|detail|patch|report|results|stats" ;;
  esac
  build_json "survey_id study_id include_structure structure_presentation query cursor limit" "${qtail[@]+"${qtail[@]}"}"
  merge_raw_json
  invoke "$tool" "$BUILT_JSON"
  ;;

billing)
  sub="${TAIL[0]:-}"
  btail=("${TAIL[@]:1}")

  case "$sub" in
    balance)
      invoke cookiy_balance_get '{}'
      ;;
    checkout)
      build_json "amount_usd_cents" "${btail[@]+"${btail[@]}"}"
      merge_raw_json
      invoke cookiy_billing_cash_checkout "$BUILT_JSON"
      ;;
    *) die "billing balance|checkout" ;;
  esac
  ;;

*)
  die "Unknown command: $CMD
$(usage)"
  ;;

esac
