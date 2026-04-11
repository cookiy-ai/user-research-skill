#!/usr/bin/env bash
# Cookiy CLI — standalone shell client for Cookiy AI.
# Run this script directly in a terminal (bash cookiy.sh <command>).
# It talks to the hosted Cookiy API over HTTP (JSON-RPC / MCP wire format);
# no IDE MCP server connection or desktop app is needed.
# Requires: bash, curl, jq, grep, sed.
set -euo pipefail

VERSION="1.19.0"
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
Cookiy CLI v${VERSION}  (standalone shell client)

This is a self-contained CLI. Execute it in a terminal — it handles all
server communication internally. Do not use IDE MCP tool-call integrations;
always run: bash cookiy.sh <command>

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
  study list|create|status|upload|..  Includes guide|interview|run-synthetic-user|report
  recruit start                       Qualitative or quant recruitment (auto-detects mode)
  quant list|create|get|update|report|admin-link  Quantitative survey management (keyed by survey-id)
  billing balance|checkout|price-table

Examples:
  cookiy.sh save-token eyJhbGciOi...
  cookiy.sh help commands
  cookiy.sh study list --limit 10
  cookiy.sh study create --query "..."  --wait
  cookiy.sh study report generate --study-id 123 --skip-synthetic-interview --wait
  cookiy.sh study report wait --study-id 123 --timeout-ms 300000
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

# Inspect any JSON body for auth-error indicators (status_code 401/403 or
# error.code UNAUTHORIZED/FORBIDDEN).  If detected, call die_no_access so
# the user always sees the sign-in URL regardless of which layer returned
# the auth failure (HTTP, JSON-RPC, or MCP tool result).
check_auth_error() {
  local body="$1"
  local sc code
  sc="$(echo "$body" | jq -r 'if type == "object" then (.status_code // empty) else empty end' 2>/dev/null)" || return 0
  case "$sc" in 401|403) die_no_access ;; esac
  code="$(echo "$body" | jq -r 'if type == "object" then (.error.code // empty) else empty end' 2>/dev/null)" || return 0
  case "$code" in UNAUTHORIZED|FORBIDDEN|AUTH_REQUIRED) die_no_access ;; esac
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
    if [[ "$http" == "401" || "$http" == "403" ]]; then
      die_no_access
    fi
    echo "MCP HTTP $http — POST $MCP_ENDPOINT" >&2
    if [[ -n "${body// /}" ]]; then
      echo "$body" | head -c 4000 >&2
      echo >>/dev/stderr
    fi
    return 1
  fi
  printf '%s' "$body"
}

# Check if a JSON-RPC response has an error. Prints error message to stderr and returns 1 if so.
check_rpc_error() {
  local resp="$1"
  # Use jq to reliably extract JSON-RPC error (handles nested objects)
  local err_msg
  err_msg="$(echo "$resp" | jq -r '.error.message // empty' 2>/dev/null)"
  if [[ -n "$err_msg" ]]; then
    local err_data
    err_data="$(echo "$resp" | jq -r '.error.data // empty' 2>/dev/null)"
    if [[ -n "$err_data" ]]; then
      echo "$err_msg: $err_data" >&2
    else
      echo "$err_msg" >&2
    fi
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

# Read cookiy_balance_get printable envelope JSON on stdin; print balance.
# Supports both old format (.data.balance_summary) and new wallet format (.data.balance + .data.formatted).
# On failure (ok != true), print error message to stderr and return 1. Uses jq only.
print_balance_summary_only() {
  local raw
  raw="$(cat)"
  if ! echo "$raw" | jq -e '.ok == true' >/dev/null 2>&1; then
    echo "$raw" | jq -r '.error.message // .error.code // "MCP request failed"' >&2
    return 1
  fi
  echo "$raw" | jq -r '
    if .data.balance_summary then .data.balance_summary
    elif .data.formatted then "Wallet balance: \(.data.formatted) (\(.data.balance // 0) cents)"
    else empty
    end'
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
  check_auth_error "$init_resp"
  check_rpc_error "$init_resp" || die "MCP initialize error"

  # 2) notifications/initialized
  post_jsonrpc '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null 2>&1 || true

  # 3) tools/call
  local call_resp
  call_resp="$(post_jsonrpc "{\"jsonrpc\":\"2.0\",\"id\":$(next_id),\"method\":\"tools/call\",\"params\":{\"name\":\"${tool_name}\",\"arguments\":${args_json}}}")" \
    || die "MCP tools/call request failed"
  check_auth_error "$call_resp"
  check_rpc_error "$call_resp" || exit 1

  local printable
  printable="$(echo "$call_resp" | emit_mcp_tool_printable)"
  check_auth_error "$printable"
  echo "$printable"
  # Exit non-zero if MCP tool returned ok:false
  if echo "$printable" | jq -e '.ok == false' >/dev/null 2>&1; then
    return 1
  fi
}

wait_for_report_completion_via_link() {
  local study_id="$1"
  local timeout_ms="${2:-300000}"  # default 5 min to prevent infinite loop
  local started_ms now_ms elapsed_ms
  started_ms="$(date +%s000)"

  while true; do
    local result status
    result="$(invoke cookiy_report_share_link_get "{\"study_id\":\"$(json_escape "$study_id")\"}")" || return 1
    status="$(echo "$result" | jq -r '.data.status // .data.report_status // empty')"

    case "$status" in
      completed)
        echo "$result"
        return 0
        ;;
      failed)
        echo "$result"
        return 1
        ;;
    esac

    if [[ -n "$timeout_ms" ]]; then
      now_ms="$(date +%s000)"
      elapsed_ms=$((now_ms - started_ms))
      if (( elapsed_ms >= timeout_ms )); then
        echo "$result"
        return 1
      fi
    fi

    sleep 10
  done
}

# --- arg builder -----------------------------------------------------------
# Parses --key value pairs from "$@" and builds a JSON object.
# Only includes keys listed in the allowed-keys spec.
# Usage: build_json "key1 key2 key3" "$@"
# Numeric keys: limit, amount_usd_cents, persona_count, incremental_participants,
#   max_chars, top_values_per_question, sample_open_text_values
# survey_id: digits only → JSON number (LimeSurvey sid); otherwise string
# Boolean keys: include_structure, include_raw (interview list always sends include_simulation=true)
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
      # Special flags: never forwarded as tool JSON fields
      if [[ "$key" == "wait" ]]; then ARG_WAIT="$val"; continue; fi
      if [[ "$key" == "json" ]]; then ARG_JSON_RAW="$val"; continue; fi
      # Skip if not in allowed list
      case " $allowed " in
        *" $key "*) ;;
        *) echo "Warning: unknown flag --${key//_/-} (ignored)" >&2; continue ;;
      esac
      $first || json+=","
      first=false
      case "$key" in
        limit|amount_usd_cents|persona_count|incremental_participants|timeout_ms|max_chars|top_values_per_question|sample_open_text_values)
          [[ "$val" =~ ^-?[0-9]+$ ]] || die "--${key//_/-} requires an integer, got: $val"
          # amount_usd_cents → MCP param name amount_cents
          local json_key="$key"
          [[ "$key" == "amount_usd_cents" ]] && json_key="amount_cents"
          json+="\"$json_key\":$val" ;;
        survey_id)
          if [[ "$val" =~ ^[0-9]+$ ]]; then json+="\"$key\":$val"
          else json+="\"$key\":\"$(json_escape "$val")\""; fi ;;
        include_structure|include_raw|skip_synthetic_interview)
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
    cookiy.sh — standalone Cookiy AI CLI (bash, curl, jq)

SYNOPSIS
    cookiy.sh [GLOBAL OPTION ...] <command> [ARG ...]

VERSION
    ${VERSION}

DESCRIPTION
    Self-contained shell client for the Cookiy AI platform. All server
    communication is handled internally via HTTP (JSON-RPC / MCP wire
    format). To use Cookiy, run this script in a terminal — do not invoke
    MCP tools through an IDE integration or desktop app.

    Long options use kebab-case; they are sent as snake_case JSON fields (e.g. --study-id → study_id).
    --wait passes server-side wait flags (no bash polling).
    --json merges extra JSON fields into the tool request, or provides the guide patch payload.
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

study create — create study from natural language
    Usage:   cookiy.sh study create --query <s> [--thinking <s>] [--attachments <s>] [--wait] [--timeout-ms <n>]
    Flags:   --query <string> (required)
             --thinking <string>   --attachments <string>   --wait (MCP wait_for_guide)   --timeout-ms (optional)

study status — study record and activity
    Usage:   cookiy.sh study status --study-id <uuid>
    Flags:   --study-id (required)
    Calls both cookiy_study_get and cookiy_activity_get for the study.

study guide get
    Usage:   cookiy.sh study guide get --study-id <uuid>
    Flags:   --study-id (required)

study guide update — apply patch to discussion guide
    Usage:   cookiy.sh study guide update --study-id <uuid> --base-revision <s> --idempotency-key <s> [--change-message <s>] --json '<patch>'
    Flags:   --study-id (required)   --base-revision (required)   --idempotency-key (required)   --json (required)
             --change-message

study upload — attach media (image upload)
    Usage:   cookiy.sh study upload --content-type <s> (--image-data <s> | --image-url <s>)
    Flags:   --content-type (required)   --image-data | --image-url (one required)

study interview list | playback url|content
    Usage:   cookiy.sh study interview list --study-id <uuid> [--cursor <s>]
             cookiy.sh study interview playback url --study-id <uuid> [--interview-id <uuid>]
             cookiy.sh study interview playback content --study-id <uuid> [--interview-id <uuid>]
    Note:    list always includes synthetic interviews in results (not configurable via CLI).

study run-synthetic-user start — run synthetic user interviews
    Usage:   cookiy.sh study run-synthetic-user start --study-id <uuid> [--persona-count <n>] [--plain-text <s>] [--wait] [--timeout-ms <n>]
    Flags:   --study-id (required)
             --persona-count <integer>  Number of synthetic interviews to run
             --plain-text <string>  Participant persona / profile description (maps to MCP interviewee_persona)
             --wait (MCP wait)   --timeout-ms (optional)

recruit start — launch participant recruitment
    Usage:   cookiy.sh recruit start [--study-id <uuid>] [--survey-public-url <url>] [--confirmation-token <s>] [--plain-text <s>] [--incremental-participants <n>]
    Flags:   --study-id (qualitative — required for interview studies)
             --survey-public-url (quant — auto-sets recruit_mode=quant_survey; study-id optional)
    Output:  Preview (confirmation_required): {preview_only, confirmation_token, recruit_mode, source_language, derived_languages, sample_size, target_group, payment_quote, status_message} (null fields omitted). HTTP 402: adds checkout_url, quote, payment_summary, payment_breakdown, retry_*. HTTP 409 (sample size reached): {ok, status_code, code, sample_size, completed_participants}. Other successes/errors: full MCP envelope JSON.
    Note:    incremental_participants is auto-capped to remaining sample size capacity. If below current channel target, treated as incremental ("recruit N more").

study report generate | content | link
    Usage:   cookiy.sh study report generate --study-id <uuid> [--skip-synthetic-interview] [--wait]
             cookiy.sh study report content --study-id <uuid> [--wait] [--timeout-ms <n>]
             cookiy.sh study report link --study-id <uuid>
    generate with --wait polls report link every 10s until status=completed (or failed/timeout).

quant list — list surveys
    Usage:   cookiy.sh quant list
    Note:    Lists all surveys visible to the operator (sid, title, active, language).

quant create — create survey (multi-language)
    Usage:   cookiy.sh quant create --json '<obj>'
    Flags:   --json (required): JSON with survey_title, languages[], groups[], quotas[], etc.
    Multi-lang: Set "languages":["en","zh","ja"] and use per-language maps for text fields.
                Respondents can switch language on the survey page.
    Schema:  See cookiy-quant-create-schema.md for full field reference.

quant get — survey detail with structure
    Usage:   cookiy.sh quant get --survey-id <n> [--include-structure <bool>]
    Flags:   --survey-id (required, numeric)
             --include-structure <bool>            Load group/question structure (default: true)
    Note:    structure_presentation defaults to json for CLI.

quant update — patch survey
    Usage:   cookiy.sh quant update --survey-id <n> --json '<obj>'
    Flags:   --survey-id (required, numeric)
             --json (required): JSON with survey, groups, questions, quotas_create, quotas_update, etc.

quant report — survey report
    Usage:   cookiy.sh quant report --survey-id <n> [--include-raw <bool>]
    Flags:   --survey-id (required, numeric)
             --include-raw <bool>   Include raw response rows (default: false)

quant admin-link — auto-login URL into the LimeSurvey admin UI for the calling user
    Usage:   cookiy.sh quant admin-link [--survey-id <n>]
    Flags:   --survey-id (optional, numeric): when provided, the URL deep-links to that
                                              survey's edit page; when omitted, lands on
                                              the admin home filtered to surveys you own.
    Output:  JSON with admin_login_url (one-time, 60-second TTL), ls_uid, ls_username.
             Open admin_login_url in a browser to land directly inside LimeSurvey as your
             own per-user account — the URL is signed by Cookiy and verified by the
             CookiyBridge LimeSurvey plugin, no manual login needed.
    Note:    "admin" here refers to LimeSurvey's URL prefix /index.php/admin/ for its
             back-office UI, not a privilege level. Each Cookiy MCP user lands as their
             own per-user LimeSurvey account, scoped to surveys they own. If the bridge
             is not configured on the server, the response sets configured=false and the
             affordance should be hidden by the calling client.

billing balance
    Usage:   cookiy.sh billing balance
    Output:  one plain-text line: MCP .data.balance_summary only (jq).

billing checkout
    Usage:   cookiy.sh billing checkout --amount-usd-cents <n>
    Flags:   USD integer cents (min 100); internally mapped to MCP amount_cents.

billing price-table
    Usage:   cookiy.sh billing price-table
    Output:  Current pricing table for all Cookiy operations (fetched from server).

BOOLEAN FLAGS (values: true | false | 1 | 0 | yes | no | on | off)
    --include-structure   --include-raw   --skip-synthetic-interview

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
      _s1=0; _s2=0
      invoke cookiy_study_get "$BUILT_JSON" || _s1=$?
      invoke cookiy_activity_get "$BUILT_JSON" || _s2=$?
      [[ $_s1 -eq 0 && $_s2 -eq 0 ]] || exit 1
      ;;
    create)
      build_json "query thinking attachments timeout_ms" "${stail[@]+"${stail[@]}"}"
      require_key query "study create requires --query"
      payload="$BUILT_JSON"
      # --wait or --timeout-ms implies server-side wait
      if [[ "$ARG_WAIT" == "true" ]] || echo "$payload" | grep -q '"timeout_ms"'; then
        payload="$(echo "$payload" | jq -c '. + {wait_for_guide: true}')"
      fi
      invoke cookiy_study_create "$payload"
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
          [[ -n "$ARG_JSON_RAW" ]] || die "study guide update requires --json '<patch>'"
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
          build_json "study_id cursor" "${itail[@]+"${itail[@]}"}"
          require_key study_id "study interview list requires --study-id"
          BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '. + {include_simulation: true}')"
          invoke cookiy_interview_list "$BUILT_JSON"
          ;;
        playback)
          psub="${itail[0]:-}"
          ptail=("${itail[@]:1}")
          case "$psub" in
            url)
              build_json "study_id interview_id" "${ptail[@]+"${ptail[@]}"}"
              require_key study_id "study interview playback url requires --study-id"
              # Inject view=url for MCP-level filtering
              BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '. + {view: "url"}')"
              invoke cookiy_interview_playback_get "$BUILT_JSON"
              ;;
            content)
              build_json "study_id interview_id" "${ptail[@]+"${ptail[@]}"}"
              require_key study_id "study interview playback content requires --study-id"
              # Inject view=transcript for MCP-level filtering
              BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '. + {view: "transcript"}')"
              invoke cookiy_interview_playback_get "$BUILT_JSON"
              ;;
            *) die "study interview playback url|content --study-id <uuid> [--interview-id <uuid>]" ;;
          esac
          ;;
        *) die "Unknown study interview subcommand: ${isub:-}" ;;
      esac
      ;;
    run-synthetic-user)
      ssub="${stail[0]:-}"
      srest=("${stail[@]:1}")
      case "$ssub" in
        start)
          build_json "study_id persona_count plain_text timeout_ms" "${srest[@]+"${srest[@]}"}"
          require_key study_id "study run-synthetic-user start requires --study-id"
          # Map --plain-text to MCP interviewee_persona
          if echo "$BUILT_JSON" | grep -q '"plain_text"'; then
            BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '. + {interviewee_persona: .plain_text} | del(.plain_text)')"
          fi
          payload="$BUILT_JSON"
          if [[ "$ARG_WAIT" == "true" ]] || echo "$payload" | grep -q '"timeout_ms"'; then
            payload="$(echo "$payload" | jq -c '. + {wait: true}')"
          fi
          invoke cookiy_simulated_interview_generate "$payload"
          ;;
        *) die "study run-synthetic-user start" ;;
      esac
      ;;
    report)
      rsub="${stail[0]:-}"
      rrest=("${stail[@]:1}")
      case "$rsub" in
        generate)
          build_json "study_id skip_synthetic_interview" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report generate requires --study-id"
          if [[ "$ARG_WAIT" == "true" ]]; then
            _grc=0
            invoke cookiy_report_generate "$BUILT_JSON" >&2 || _grc=$?
            [[ $_grc -eq 0 ]] || exit 1
            study_id_value="$(echo "$BUILT_JSON" | jq -r '.study_id')"
            wait_for_report_completion_via_link "$study_id_value"
          else
            invoke cookiy_report_generate "$BUILT_JSON"
          fi
          ;;
        content)
          build_json "study_id timeout_ms" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report content requires --study-id"
          # --wait or --timeout-ms: poll status first, then fetch content
          if [[ "$ARG_WAIT" == "true" ]] || echo "$BUILT_JSON" | grep -q '"timeout_ms"'; then
            wait_payload="$(echo "$BUILT_JSON" | jq -c '. + {wait: true}')"
            _rrc=0
            invoke cookiy_report_status "$wait_payload" > /dev/null || _rrc=$?
            [[ $_rrc -eq 0 ]] || exit 1
          fi
          invoke cookiy_report_content_get "$(echo "$BUILT_JSON" | jq -c 'del(.timeout_ms)')"
          ;;
        link)
          build_json "study_id" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report link requires --study-id"
          invoke cookiy_report_share_link_get "$BUILT_JSON"
          ;;
        wait)
          build_json "study_id timeout_ms" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report wait requires --study-id"
          study_id_value="$(echo "$BUILT_JSON" | jq -r '.study_id')"
          timeout_ms_value="$(echo "$BUILT_JSON" | jq -r '.timeout_ms // 300000')"
          wait_for_report_completion_via_link "$study_id_value" "$timeout_ms_value"
          ;;
        *) die "study report generate|content|link|wait" ;;
      esac
      ;;
    *) die "Unknown study subcommand: ${sub:-(none)}
Available: list, create, status, upload, guide, interview, run-synthetic-user, report" ;;
  esac
  ;;

quant)
  sub="${TAIL[0]:-}"
  qtail=("${TAIL[@]:1}")

  case "$sub" in
    list)
      build_json "" "${qtail[@]+"${qtail[@]}"}"
      invoke cookiy_quant_survey_list "$BUILT_JSON"
      ;;
    create)
      build_json "" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      [[ -n "$ARG_JSON_RAW" ]] || die "quant create requires --json '<obj>'"
      invoke cookiy_quant_survey_create "$BUILT_JSON"
      ;;
    get)
      build_json "survey_id include_structure" "${qtail[@]+"${qtail[@]}"}"
      require_key survey_id "quant get requires --survey-id (numeric sid from quant list)"
      BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '.structure_presentation |= (. // "json")')"
      invoke cookiy_quant_survey_detail "$BUILT_JSON"
      ;;
    update)
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      require_key survey_id "quant update requires --survey-id (numeric sid from quant list)"
      [[ -n "$ARG_JSON_RAW" ]] || die "quant update requires --json '<obj>'"
      invoke cookiy_quant_survey_patch "$BUILT_JSON"
      ;;
    report)
      build_json "survey_id include_raw" "${qtail[@]+"${qtail[@]}"}"
      require_key survey_id "quant report requires --survey-id (numeric sid from quant list)"
      invoke cookiy_quant_survey_report "$BUILT_JSON"
      ;;
    admin-link)
      # survey_id is optional — when omitted, the URL lands on the LS admin
      # home (filtered to surveys the calling user owns). When provided, it
      # deep-links to that survey's edit page.
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
      invoke cookiy_quant_survey_admin_link "$BUILT_JSON"
      ;;
    *)
      die "quant list|create|get|update|report|admin-link"
      ;;
  esac
  ;;

recruit)
  sub="${TAIL[0]:-}"
  rtail=("${TAIL[@]:1}")

  case "$sub" in
    start)
      build_json "study_id confirmation_token plain_text incremental_participants survey_public_url" "${rtail[@]+"${rtail[@]}"}"
      # Auto-detect quant mode when --survey-public-url is provided
      if echo "$BUILT_JSON" | grep -q '"survey_public_url"'; then
        BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '. + {recruit_mode: "quant_survey"}')"
      fi
      # CLI policy: explicit reconfigure semantics (matches console UX). Live launch is enforced by MCP/V1 on confirm.
      BUILT_JSON="$(echo "$BUILT_JSON" | jq -c '. + {force_reconfigure: true}')"
      _rc=0
      result="$(invoke cookiy_recruit_create "$BUILT_JSON")" || _rc=$?
      echo "$result" | jq '
        if .ok == false and .status_code == 409 and (.data | type) == "object" then
          {
            ok: false,
            status_code: 409,
            code: .data.code,
            sample_size: .data.data.sample_size,
            completed_participants: .data.data.completed_participants
          }
        elif .ok == false and .status_code == 402 and (.data | type) == "object" then
          {
            ok: false,
            status_code: 402,
            workflow_state: .data.workflow_state,
            preview_only: .data.preview_only,
            confirmation_token: .data.confirmation_token,
            status_message: .data.status_message,
            checkout_url: .data.checkout_url,
            checkout_url_short: .data.checkout_url_short,
            checkout_id: .data.checkout_id,
            quote: .data.quote,
            payment_summary: .data.payment_summary,
            payment_breakdown: .data.payment_breakdown,
            retry_same_tool: .data.retry_same_tool,
            retry_tool_name: .data.retry_tool_name,
            retry_input_hint: .data.retry_input_hint
          }
        elif .ok == true and (.data | type) == "object" and ((.data.preview_only == true) or (.data.status == "confirmation_required")) then
          {
            preview_only: .data.preview_only,
            confirmation_token: .data.confirmation_token,
            recruit_mode: .data.recruit_mode,
            survey_public_url: .data.survey_public_url,
            source_language: .data.source_language,
            derived_languages: .data.targeting_preview.derived_languages_canonical,
            sample_size: .data.study_summary.sample_size,
            interview_duration_minutes: .data.study_summary.interview_duration_minutes,
            target_group: (.data.targeting_preview.target_persona_summary // .data.targeting_preview.target_group),
            payment_quote: .data.targeting_preview.payment_quote,
            status_message: .data.status_message
          } | with_entries(select(.value != null))
        else
          .
        end
      '
      exit $_rc
      ;;
    *) die "recruit start" ;;
  esac
  ;;

billing)
  sub="${TAIL[0]:-}"
  btail=("${TAIL[@]:1}")

  case "$sub" in
    balance)
      [[ ${#btail[@]} -eq 0 ]] || die "billing balance takes no arguments"
      _brc=0
      result="$(invoke cookiy_balance_get '{}')" || _brc=$?
      echo "$result" | print_balance_summary_only
      [[ $_brc -eq 0 ]] || exit 1
      ;;
    checkout)
      build_json "amount_usd_cents" "${btail[@]+"${btail[@]}"}"
      require_key amount_cents "billing checkout requires --amount-usd-cents <integer>"
      invoke cookiy_billing_cash_checkout "$BUILT_JSON"
      ;;
    price-table)
      [[ ${#btail[@]} -eq 0 ]] || die "billing price-table takes no arguments"
      invoke cookiy_billing_price_table '{}'
      ;;
    *) die "billing balance|checkout|price-table" ;;
  esac
  ;;

*)
  die "Unknown command: $CMD
$(usage)"
  ;;

esac
