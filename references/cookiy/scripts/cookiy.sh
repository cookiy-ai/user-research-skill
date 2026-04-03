#!/usr/bin/env bash
# Cookiy CLI — pure shell wrapper over hosted JSON-RPC using curl.
# Requires: bash, curl, jq, grep, sed.
set -euo pipefail

VERSION="1.12.0"
DEFAULT_SERVER_URL="https://s-api.cookiy.ai"
DEFAULT_TOKEN_PATH="${COOKIY_CREDENTIALS:-$HOME/.cookiy/token.txt}"
# Long-running MCP tools/call (server-side wait); override with COOKIY_MCP_RPC_TIMEOUT.
MCP_CALL_TIMEOUT="${COOKIY_MCP_RPC_TIMEOUT:-600}"
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

usage() {
  cat <<EOF
Cookiy CLI v${VERSION}  (shell)

Usage:
  cookiy.sh [--token <path>] [--mcp-url <url>] <command> ...

Global options:
  --mcp-url     Full JSON-RPC URL (overrides COOKIY_MCP_URL)
  --token       Path to raw token file (default: ~/.cookiy/token.txt; env COOKIY_CREDENTIALS)

Environment:
  COOKIY_CREDENTIALS   Path to token file (same as --token)
  COOKIY_MCP_URL       Full MCP URL (default: <server>/mcp)
  COOKIY_MCP_RPC_TIMEOUT   Seconds for blocking MCP tools/call (default: 600)
  COOKIY_SERVER_URL    API origin when MCP URL not set (default: https://s-api.cookiy.ai)

Commands:
  save-token <token>          Save raw access token (validates against MCP first)
  help                        Offline CLI reference
  study list|create|status|upload|.. Includes guide|interview|recruit|report
  quant list|create|get|update|report
  billing balance|checkout

Examples:
  cookiy.sh save-token eyJhbGciOi...
  cookiy.sh help commands
  cookiy.sh study list --limit 10
  cookiy.sh study create --query "..." --wait
EOF
}

# --- login URL + unified auth-failure handler ------------------------------

resolve_server_base() {
  local base="${SERVER_URL_OPT:-${COOKIY_SERVER_URL:-}}"
  echo "${base:-$DEFAULT_SERVER_URL}"
}

resolve_login_url() {
  echo "$(resolve_server_base)/oauth/cli/start"
}

die_no_access() {
  local url
  url="$(resolve_login_url)"
  die "Access denied — token is missing or expired.
Sign in:  $url"
}

# --- save-token command ----------------------------------------------------

run_save_token() {
  command -v jq >/dev/null 2>&1 || die "cookiy.sh requires jq"
  local input="$1"
  input="$(printf '%s' "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\r$//')"
  [[ -n "$input" ]] || die "Usage: cookiy.sh save-token <access_token_or_json>"

  local at=""
  if printf '%s' "$input" | jq -e '.access_token' >/dev/null 2>&1; then
    at="$(printf '%s' "$input" | jq -r '.access_token')"
  else
    at="$input"
  fi
  [[ -n "$at" ]] || die "Could not find access_token in input."

  local raw_server mcp_end
  raw_server="$(resolve_server_base)"
  mcp_end="${MCP_URL_OPT:-${COOKIY_MCP_URL:-}}"
  mcp_end="${mcp_end:-${raw_server%/}/mcp}"

  # Verify token works before writing
  local resp http body
  resp="$(curl -sS --max-time "$TIMEOUT" -w '\n%{http_code}' -X POST "$mcp_end" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Authorization: Bearer $at" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"cookiy-cli-sh\",\"version\":\"1.0.0\"}}}")" \
    || die "MCP verify failed (curl error). Check your network and try again."
  http="$(echo "$resp" | tail -n1)"
  body="$(echo "$resp" | sed '$d')"
  [[ "$http" == "200" ]] || die "MCP verify HTTP $http — token may be invalid or expired. Sign in again at: $(resolve_login_url)"
  if echo "$body" | jq -e '.error' >/dev/null 2>&1; then
    die "MCP verify error: $(echo "$body" | jq -c .error)"
  fi

  mkdir -p "$(dirname "$TOKEN_PATH")"
  printf '%s' "$at" > "$TOKEN_PATH"
  chmod 600 "$TOKEN_PATH" 2>/dev/null || true

  echo "Token verified and saved to $TOKEN_PATH" >&2
}

# --- token file & URL resolution ------------------------------------------

TOKEN_PATH="$DEFAULT_TOKEN_PATH"
SERVER_URL_OPT=""
MCP_URL_OPT=""
ACCESS_TOKEN=""
MCP_ENDPOINT=""

load_credentials() {
  [[ -f "$TOKEN_PATH" ]] || die_no_access
  ACCESS_TOKEN="$(tr -d '\r\n' < "$TOKEN_PATH" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -n "$ACCESS_TOKEN" ]] || die_no_access
}

resolve_mcp_endpoint() {
  if [[ -n "$MCP_URL_OPT" ]]; then MCP_ENDPOINT="$MCP_URL_OPT"; return; fi
  if [[ -n "${COOKIY_MCP_URL:-}" ]]; then MCP_ENDPOINT="$COOKIY_MCP_URL"; return; fi
  local base="${SERVER_URL_OPT:-${COOKIY_SERVER_URL:-}}"
  base="${base:-$DEFAULT_SERVER_URL}"
  MCP_ENDPOINT="${base%/}/mcp"
}

# --- JSON-RPC over curl ----------------------------------------------------

# POST JSON-RPC body to MCP_ENDPOINT; print response body on HTTP 200 only.
# On failure: print HTTP code, response snippet, and curl errors to stderr; return 1.
post_jsonrpc() {
  local payload="$1"
  local resp http body cerr
  cerr="$(mktemp -t cookiycurl.XXXXXX 2>/dev/null || mktemp)"
  resp="$(curl -sS --max-time "$MCP_CALL_TIMEOUT" -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$payload" \
    "$MCP_ENDPOINT" 2>"$cerr")" || {
    [[ -s "$cerr" ]] && echo "curl: $(cat "$cerr")" >&2
    rm -f "$cerr"
    return 1
  }
  rm -f "$cerr"
  http="$(printf '%s' "$resp" | tail -n1)"
  body="$(printf '%s' "$resp" | sed '$d')"
  if [[ "$http" != "200" ]]; then
    echo "MCP HTTP $http — POST $MCP_ENDPOINT" >&2
    if [[ -n "${body// /}" ]]; then
      echo "$body" | head -c 4000 >&2
      echo >>/dev/stderr
    fi
    if [[ "$http" == "401" || "$http" == "403" ]]; then
      die_no_access
    fi
    return 1
  fi
  printf '%s' "$body"
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

# Read full JSON-RPC tools/call response on stdin; print like Node renderResult:
# result.structuredContent if that key exists, else result. Pretty JSON. Uses jq only.
emit_mcp_tool_printable() {
  local raw
  raw="$(cat)"
  echo "$raw" | jq '
    .result as $r
    | if ($r | type) == "object" and ($r | has("structuredContent"))
      then $r.structuredContent
      else $r
      end
  '
}

# Read cookiy_balance_get printable envelope JSON on stdin; print only .data.balance_summary (plain text, no quotes).
# On failure (ok != true), print error message to stderr and return 1. Uses jq only.
print_balance_summary_only() {
  local raw
  raw="$(cat)"
  if ! echo "$raw" | jq -e '.ok == true' >/dev/null 2>&1; then
    echo "$raw" | jq -r '.error.message // .error.code // "MCP request failed"' >&2
    return 1
  fi
  echo "$raw" | jq -r '.data.balance_summary // empty'
}

# invoke <tool_name> <arguments_json>
# Performs the 3-step MCP handshake: initialize, notify, tools/call
invoke() {
  command -v jq >/dev/null 2>&1 || die "cookiy.sh requires jq"
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

  echo "$call_resp" | emit_mcp_tool_printable
}

# --- arg builder -----------------------------------------------------------
# Parses --key value pairs from "$@" and builds a JSON object.
# Only includes keys listed in the allowed-keys spec.
# Usage: build_json "key1 key2 key3" "$@"
# Numeric keys: limit, amount_usd_cents, persona_count, target_participants
# survey_id: digits only → JSON number (LimeSurvey sid); otherwise string
# Boolean keys: include_simulation, include_structure, auto_generate_personas
# The rest are strings.
# Sets global: BUILT_JSON, ARG_WAIT, ARG_JSON_RAW, ARG_POSITIONALS

ARG_WAIT=""
ARG_JSON_RAW=""
ARG_POSITIONALS=""

# CLI string → JSON true/false (for MCP tools that expect boolean, not "true" strings)
bool_json() {
  case "$1" in
    true|True|TRUE|1|yes|Yes|YES|on|On|ON) echo true ;;
    false|False|FALSE|0|no|No|NO|off|Off|OFF) echo false ;;
    *) die "Invalid boolean value: $1 (use true or false)" ;;
  esac
}

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
      case "$key" in
        limit|amount_usd_cents|persona_count|target_participants|timeout_ms)
          # amount_usd_cents → MCP param name amount_cents
          local json_key="$key"
          [[ "$key" == "amount_usd_cents" ]] && json_key="amount_cents"
          json+="\"$json_key\":$val" ;;
        survey_id)
          if [[ "$val" =~ ^[0-9]+$ ]]; then json+="\"$key\":$val"
          else json+="\"$key\":\"$(json_escape "$val")\""; fi ;;
        include_simulation|include_structure|auto_generate_personas)
          json+="\"$key\":$(bool_json "$val")" ;;
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

# Require key present and value not empty string (still allows numeric / non-string JSON values)
require_non_empty_string_value() {
  local key="$1" msg="$2"
  require_key "$key" "$msg"
  if echo "$BUILT_JSON" | grep -qE "\"$key\"[[:space:]]*:[[:space:]]*\"\"(,|})"; then
    die "$msg"
  fi
}

# Get a string value from BUILT_JSON
built_get() {
  echo "$BUILT_JSON" | json_get "$1"
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

# Local CLI reference (no credentials; printed by: help | help commands | help cli)
# Layout: POSIX/man-inspired sections; Usage + Flags blocks similar to Cobra/docker-style --help.
print_cli_commands_reference() {
  cat <<EOF
NAME
    cookiy.sh — Cookiy hosted API client (bash, JSON-RPC)

SYNOPSIS
    cookiy.sh [GLOBAL OPTION ...] <command> [ARG ...]

VERSION
    ${VERSION}

DESCRIPTION
    Long options use kebab-case; they are sent as snake_case JSON fields (e.g. --study-id → study_id).
    --wait passes server-side wait flags to MCP tools (no bash polling). --json merges extra fields.
    Numeric sid for quant: --survey-id 12345 becomes JSON number when value is all digits.

GLOBAL OPTIONS
    --token <path>    Raw token file (default ~/.cookiy/token.txt; same as COOKIY_CREDENTIALS)
    --mcp-url <url>   Full JSON-RPC URL (overrides COOKIY_MCP_URL)

ENVIRONMENT
    COOKIY_CREDENTIALS      Path to raw token file
    COOKIY_MCP_URL          Full MCP JSON-RPC URL
    COOKIY_MCP_RPC_TIMEOUT  Max seconds for tools/call (default 600)
    COOKIY_SERVER_URL       API origin if MCP URL not set

DOCUMENTATION
    references/cookiy/cli/commands.md  (if present in repo)

COMMANDS

help — offline CLI reference
    Usage:   cookiy.sh help
    Note:    Prints this reference. No credentials needed.

study list — list studies
    Usage:   cookiy.sh study list [--limit <n>] [--cursor <s>]
    Flags:   --limit <integer>   --cursor <string>

study guide create — create study from natural language
    Usage:   cookiy.sh study guide create --query <s> [--thinking <s>] [--attachments <s>] [--wait] [--timeout-ms <n>]
    Flags:   --query <string> (required)
             --thinking <string>   --attachments <string>   --wait (MCP wait_for_guide)   --timeout-ms (optional)

study status — study record and activity
    Usage:   cookiy.sh study status --study-id <uuid>
    Flags:   --study-id (required)
    Calls both cookiy_study_get and cookiy_activity_get for the study.

study guide wait | get
    Usage:   cookiy.sh study guide wait --study-id <uuid> [--timeout-ms <n>]
             cookiy.sh study guide get --study-id <uuid>
    Flags:   --study-id (required)
    study guide wait blocks until guide ready/failed or timeout (server-side).

study guide update — apply patch to discussion guide
    Usage:   cookiy.sh study guide update --study-id <uuid> --base-revision <s> --idempotency-key <s> --json '<patch>' [--change-message <s>]
    Flags:   --study-id (required)   --base-revision (required)   --idempotency-key (required)   --json (required)
             --change-message

study upload — attach media (image upload)
    Usage:   cookiy.sh study upload --content-type <s> (--image-data <s> | --image-url <s>)
    Flags:   --content-type (required)   --image-data | --image-url (one required)

study interview list | playback [url|content] | simulate start|wait
    Usage:   cookiy.sh study interview list --study-id <uuid> [--include-simulation <bool>] [--cursor <s>]
             cookiy.sh study interview playback --study-id <uuid> [--interview-id <uuid>]
             cookiy.sh study interview playback url --study-id <uuid> [--interview-id <uuid>]
             cookiy.sh study interview playback content --study-id <uuid> [--interview-id <uuid>]
             cookiy.sh study interview simulate start --study-id <uuid> [--persona-count <n>] [--auto-generate-personas <bool>] [--interviewee-persona <s>] [--wait] [--timeout-ms <n>] [--json '<obj>']
             cookiy.sh study interview simulate wait --study-id <uuid> --job-id <uuid> [--timeout-ms <n>]

study recruit start
    Usage:   cookiy.sh study recruit start --study-id <uuid> [--confirmation-token <s>] [--plain-text <s>] [--target-participants <n>]

study report content | link
    Usage:   cookiy.sh study report content --study-id <uuid> [--wait] [--timeout-ms <n>]
             cookiy.sh study report link --study-id <uuid>
    report content with --wait or --timeout-ms polls server-side until PREVIEW/READY or timeout.

quant list — list surveys
    Usage:   cookiy.sh quant list [--study-id <uuid>] [--json '<obj>']
    Flags:   --study-id (optional)

quant create — create survey
    Usage:   cookiy.sh quant create [--study-id <uuid>] --json '<obj>'
    Flags:   --study-id (optional)   --json (required: survey_title, groups[], etc.)

quant get — survey detail with structure
    Usage:   cookiy.sh quant get --survey-id <n> [--study-id <uuid>] [--language <s>] [--include-structure <bool>] [--structure-presentation <s>] [--json '<obj>']
    Flags:   --survey-id (required, numeric)   --study-id   --language   --include-structure   --structure-presentation

quant update — patch survey
    Usage:   cookiy.sh quant update --survey-id <n> --json '<obj>'
    Flags:   --survey-id (required, numeric)   --json (required: survey, groups, questions, etc.)

quant report — survey report
    Usage:   cookiy.sh quant report --survey-id <n> [--json '<obj>']
    Flags:   --survey-id (required, numeric)   --json (optional: language, completion_status, etc.)

billing balance
    Usage:   cookiy.sh billing balance
    Output:  one plain-text line: MCP .data.balance_summary only (jq).

billing checkout
    Usage:   cookiy.sh billing checkout --amount-usd-cents <n> [--json '<obj>']
    Flags:   USD integer cents (min 100); internally mapped to MCP amount_cents.

BOOLEAN FLAGS (values: true | false | 1 | 0 | yes | no | on | off)
    --include-simulation   --include-structure   --auto-generate-personas

save-token — store raw access token from browser sign-in
    Usage:   cookiy.sh save-token <access_token>
             cookiy.sh save-token '{"access_token":"eyJ..."}'
    Flow:    Verifies the token against MCP, then writes raw token to --token path.
    Get token: open the sign-in page at {server}/oauth/cli/start, log in, copy the token.
    Needs:   jq, curl

FILES
    Default token file: ~/.cookiy/token.txt
EOF
}

# === Parse global options ==================================================

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Undocumented in usage/help; for internal API base override only.
    --server-url)  SERVER_URL_OPT="$2"; shift 2 ;;
    --mcp-url)     MCP_URL_OPT="$2"; shift 2 ;;
    --token|--credentials) TOKEN_PATH="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
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

# Local CLI manual: no credentials needed
if [[ "$CMD" == "help" ]]; then
  print_cli_commands_reference
  exit 0
fi

# save-token: no prior credentials required
if [[ "$CMD" == "save-token" ]]; then
  [[ ${#TAIL[@]} -ge 1 ]] || die "Usage: cookiy.sh save-token <access_token_or_json>"
  run_save_token "${TAIL[*]}"
  exit 0
fi


# All commands below need credentials
load_credentials
resolve_mcp_endpoint

# === COMMANDS ==============================================================

case "$CMD" in

study)
  sub="${TAIL[0]:-}"
  stail=("${TAIL[@]:1}")

  case "$sub" in
    list)
      build_json "limit cursor" "${stail[@]+"${stail[@]}"}"
      invoke cookiy_study_list "$BUILT_JSON"
      ;;
    status)
      build_json "study_id" "${stail[@]+"${stail[@]}"}"
      require_key study_id "study status requires --study-id"
      invoke cookiy_study_get "$BUILT_JSON"
      invoke cookiy_activity_get "$BUILT_JSON"
      ;;
    upload)
      build_json "image_data image_url content_type" "${stail[@]+"${stail[@]}"}"
      require_key content_type "study upload requires --content-type"
      invoke cookiy_media_upload "$BUILT_JSON"
      ;;
    guide)
      gcmd="${stail[0]:-}"
      gtail=("${stail[@]:1}")
      case "$gcmd" in
        create)
          build_json "query thinking attachments timeout_ms" "${gtail[@]+"${gtail[@]}"}"
          require_key query "study guide create requires --query"
          payload="$BUILT_JSON"
          # --wait or --timeout-ms implies server-side wait
          if [[ "$ARG_WAIT" == "true" ]] || echo "$payload" | grep -q '"timeout_ms"'; then
            payload="$(echo "$payload" | jq -c '. + {wait_for_guide: true}')"
          fi
          invoke cookiy_study_create "$payload"
          ;;
        wait)
          build_json "study_id timeout_ms" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide wait requires --study-id"
          invoke cookiy_guide_status "$(echo "$BUILT_JSON" | jq -c '. + {wait: true}')"
          ;;
        get)
          build_json "study_id" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide get requires --study-id"
          invoke cookiy_guide_get "$BUILT_JSON"
          ;;
        update)
          build_json "study_id base_revision idempotency_key change_message" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide update requires --study-id"
          require_key base_revision "study guide update requires --base-revision"
          require_key idempotency_key "study guide update requires --idempotency-key"
          [[ -n "$ARG_JSON_RAW" ]] || die "study guide update requires --json"
          # Inject patch key: strip trailing }, append ,"patch":...}
          BUILT_JSON="${BUILT_JSON%\}},\"patch\":$ARG_JSON_RAW}"
          invoke cookiy_guide_patch "$BUILT_JSON"
          ;;
        *) die "Unknown: study guide ${gcmd:-}" ;;
      esac
      ;;
    interview)
      isub="${stail[0]:-}"
      itail=("${stail[@]:1}")
      case "$isub" in
        list)
          build_json "study_id include_simulation cursor" "${itail[@]+"${itail[@]}"}"
          require_key study_id "study interview list requires --study-id"
          invoke cookiy_interview_list "$BUILT_JSON"
          ;;
        playback)
          psub="${itail[0]:-}"
          ptail=("${itail[@]:1}")
          case "$psub" in
            url)
              build_json "study_id interview_id" "${ptail[@]+"${ptail[@]}"}"
              require_key study_id "study interview playback url requires --study-id"
              result="$(invoke cookiy_interview_playback_get "$BUILT_JSON")"
              echo "$result" | jq '{playback_page_url: (.interviews // [. ])[].playback_page_url, playback_page_expires_at: (.interviews // [. ])[].playback_page_expires_at}'
              ;;
            content)
              build_json "study_id interview_id" "${ptail[@]+"${ptail[@]}"}"
              require_key study_id "study interview playback content requires --study-id"
              result="$(invoke cookiy_interview_playback_get "$BUILT_JSON")"
              echo "$result" | jq '{transcript: (.interviews // [. ])[].transcript, turn_count: (.interviews // [. ])[].turn_count, transcript_available: (.interviews // [. ])[].transcript_available}'
              ;;
            --*|"")
              # No subcommand — return full playback (default behavior)
              build_json "study_id interview_id" "${itail[@]+"${itail[@]}"}"
              require_key study_id "study interview playback requires --study-id"
              invoke cookiy_interview_playback_get "$BUILT_JSON"
              ;;
            *) die "study interview playback [url|content] --study-id <uuid> [--interview-id <uuid>]" ;;
          esac
          ;;
        simulate)
          ssub="${itail[0]:-}"
          srest=("${itail[@]:1}")
          case "$ssub" in
            start)
              build_json "study_id auto_generate_personas persona_count interviewee_persona timeout_ms" "${srest[@]+"${srest[@]}"}"
              merge_raw_json
              require_key study_id "study interview simulate start requires --study-id"
              payload="$BUILT_JSON"
              # --wait or --timeout-ms implies server-side wait
              if [[ "$ARG_WAIT" == "true" ]] || echo "$payload" | grep -q '"timeout_ms"'; then
                payload="$(echo "$payload" | jq -c '. + {wait: true}')"
              fi
              invoke cookiy_simulated_interview_generate "$payload"
              ;;
            wait)
              build_json "study_id job_id timeout_ms" "${srest[@]+"${srest[@]}"}"
              require_key study_id "study interview simulate wait requires --study-id"
              require_non_empty_string_value job_id "study interview simulate wait requires --job-id"
              invoke cookiy_simulated_interview_status "$(echo "$BUILT_JSON" | jq -c '. + {wait: true}')"
              ;;
            *) die "study interview simulate start|wait" ;;
          esac
          ;;
        *) die "Unknown study interview subcommand: ${isub:-}" ;;
      esac
      ;;
    recruit)
      rsub="${stail[0]:-}"
      rrest=("${stail[@]:1}")
      case "$rsub" in
        start)
          build_json "study_id confirmation_token plain_text target_participants" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study recruit start requires --study-id"
          invoke cookiy_recruit_create "$BUILT_JSON"
          ;;
        *) die "study recruit start" ;;
      esac
      ;;
    report)
      rsub="${stail[0]:-}"
      rrest=("${stail[@]:1}")
      case "$rsub" in
        content)
          build_json "study_id timeout_ms" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report content requires --study-id"
          payload="$BUILT_JSON"
          # --wait or --timeout-ms implies server-side wait
          if [[ "$ARG_WAIT" == "true" ]] || echo "$payload" | grep -q '"timeout_ms"'; then
            payload="$(echo "$payload" | jq -c '. + {wait: true}')"
          fi
          invoke cookiy_report_status "$payload"
          ;;
        link)
          build_json "study_id" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report link requires --study-id"
          invoke cookiy_report_share_link_get "$BUILT_JSON"
          ;;
        *) die "study report content|link" ;;
      esac
      ;;
    *) die "Unknown study subcommand: ${sub:-}" ;;
  esac
  ;;

quant)
  sub="${TAIL[0]:-}"
  qtail=("${TAIL[@]:1}")

  case "$sub" in
    list)
      build_json "study_id" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      invoke cookiy_quant_survey_list "$BUILT_JSON"
      ;;
    create)
      build_json "study_id" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      invoke cookiy_quant_survey_create "$BUILT_JSON"
      ;;
    get)
      build_json "survey_id study_id language include_structure structure_presentation" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      require_key survey_id "quant get requires --survey-id (numeric sid from quant list)"
      invoke cookiy_quant_survey_detail "$BUILT_JSON"
      ;;
    update)
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      require_key survey_id "quant update requires --survey-id (numeric sid from quant list)"
      invoke cookiy_quant_survey_patch "$BUILT_JSON"
      ;;
    report)
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      require_key survey_id "quant report requires --survey-id (numeric sid from quant list)"
      invoke cookiy_quant_survey_report "$BUILT_JSON"
      ;;
    *)
      die "quant list|create|get|update|report"
      ;;
  esac
  ;;

billing)
  sub="${TAIL[0]:-}"
  btail=("${TAIL[@]:1}")

  case "$sub" in
    balance)
      [[ ${#btail[@]} -eq 0 ]] || die "billing balance takes no arguments"
      result="$(invoke cookiy_balance_get '{}')"
      echo "$result" | print_balance_summary_only
      ;;
    checkout)
      build_json "amount_usd_cents" "${btail[@]+"${btail[@]}"}"
      merge_raw_json
      require_key amount_cents "billing checkout requires --amount-usd-cents <integer> (or --json with amount_cents)"
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
