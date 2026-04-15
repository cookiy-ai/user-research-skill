#!/usr/bin/env bash
# Cookiy CLI — standalone shell client for Cookiy AI.
# Run in a terminal: bash cookiy.sh <command>
# Requires: bash, curl, jq, grep, sed.
set -euo pipefail

VERSION="1.21.0"
DEFAULT_SERVER_URL="https://s-api.cookiy.ai"
DEFAULT_TOKEN_PATH="${COOKIY_CREDENTIALS:-$HOME/.cookiy/token.txt}"
# Long-running API call timeout (seconds); override with COOKIY_API_RPC_TIMEOUT or legacy COOKIY_MCP_RPC_TIMEOUT.
API_CALL_TIMEOUT="${COOKIY_API_RPC_TIMEOUT:-${COOKIY_MCP_RPC_TIMEOUT:-600}}"
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

# Add or overwrite a key in BUILT_JSON.  Value must be a raw JSON literal
# (e.g. '"url"', 'true', '300000').
json_set() {
  local key="$1" val="$2"
  # Remove existing key (if any) then append
  BUILT_JSON="$(printf '%s' "$BUILT_JSON" | sed 's/,"'"$key"'":[^,}]*//;s/{"'"$key"'":[^,}]*,/{/')"
  BUILT_JSON="${BUILT_JSON%\}},\"$key\":$val}"
}

# Remove a key from BUILT_JSON.
json_del() {
  local key="$1"
  BUILT_JSON="$(printf '%s' "$BUILT_JSON" | sed 's/,"'"$key"'":[^,}]*//;s/{"'"$key"'":[^,}]*,/{/')"
  # Handle case where it's the only key
  BUILT_JSON="$(printf '%s' "$BUILT_JSON" | sed 's/{"'"$key"'":[^}]*}/{}/')"
}

# Read a string/number value from BUILT_JSON (no jq).
built_get() {
  echo "$BUILT_JSON" | json_get "$1"
}

# Read a numeric value with fallback default (no jq).
built_get_num() {
  local val
  val="$(echo "$BUILT_JSON" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)"
  echo "${val:-$2}"
}

usage() {
  cat <<EOF
Cookiy CLI v${VERSION}  (standalone shell client)

Run in a terminal: bash cookiy.sh <command>

Usage:
  cookiy.sh [--token <path>] [--api-url <url>] <command> ...

Global options:
  --api-url     Full JSON-RPC endpoint URL (overrides COOKIY_API_URL)
  --token       Path to raw token file (default: ~/.cookiy/token.txt; env COOKIY_CREDENTIALS)

Environment:
  COOKIY_CREDENTIALS       Path to token file (same as --token)
  COOKIY_API_URL           Full API endpoint URL (default: <server>/mcp)
  COOKIY_API_RPC_TIMEOUT   Seconds for blocking API calls (default: 600)
  COOKIY_SERVER_URL        API origin when endpoint URL not set (default: https://s-api.cookiy.ai)

Commands:
  save-token <token>          Save raw access token (validates against API first)
  help                        Offline CLI reference
  study list|create|status|upload|..  Includes guide|interview|run-synthetic-user|report
  recruit start                       Qualitative or quant recruitment (auto-detects mode)
  quant list|create|get|update|status|report|admin-link  Quantitative survey management (keyed by survey-id)
  billing balance|checkout|price-table|transactions

Examples:
  cookiy.sh save-token eyJhbGciOi...
  cookiy.sh help commands
  cookiy.sh study list --limit 10
  cookiy.sh study create --query "..."  --wait
  cookiy.sh study report generate --study-id 123 --skip-synthetic-interview --wait
  cookiy.sh study report wait --study-id 123 --timeout-ms 300000
  cookiy.sh billing transactions --limit 50
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
# the auth failure (HTTP, JSON-RPC, or tool result).
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

  local raw_server api_end
  raw_server="$(resolve_server_base)"
  api_end="${API_URL_OPT:-${COOKIY_API_URL:-${COOKIY_MCP_URL:-}}}"
  api_end="${api_end:-${raw_server%/}/mcp}"

  # Verify token works before writing
  local resp http body
  resp="$(curl -sS --max-time "$TIMEOUT" -w '\n%{http_code}' -X POST "$api_end" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Authorization: Bearer $at" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"cookiy-cli-sh\",\"version\":\"1.0.0\"}}}")" \
    || die "Token verify failed (curl error). Check your network and try again."
  http="$(echo "$resp" | tail -n1)"
  body="$(echo "$resp" | sed '$d')"
  [[ "$http" == "200" ]] || die "Token verify HTTP $http — token may be invalid or expired. Sign in again at: $(resolve_login_url)"
  if echo "$body" | jq -e '.error' >/dev/null 2>&1; then
    die "Token verify error: $(echo "$body" | jq -c .error)"
  fi

  mkdir -p "$(dirname "$TOKEN_PATH")"
  printf '%s' "$at" > "$TOKEN_PATH"
  chmod 600 "$TOKEN_PATH" 2>/dev/null || true

  echo "Token verified and saved to $TOKEN_PATH" >&2
}

# --- token file & URL resolution ------------------------------------------

TOKEN_PATH="$DEFAULT_TOKEN_PATH"
SERVER_URL_OPT=""
API_URL_OPT=""
ACCESS_TOKEN=""
API_ENDPOINT=""

load_credentials() {
  [[ -f "$TOKEN_PATH" ]] || die_no_access
  ACCESS_TOKEN="$(tr -d '\r\n' < "$TOKEN_PATH" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -n "$ACCESS_TOKEN" ]] || die_no_access
}

resolve_api_endpoint() {
  if [[ -n "$API_URL_OPT" ]]; then API_ENDPOINT="$API_URL_OPT"; return; fi
  if [[ -n "${COOKIY_API_URL:-${COOKIY_MCP_URL:-}}" ]]; then API_ENDPOINT="${COOKIY_API_URL:-${COOKIY_MCP_URL:-}}"; return; fi
  local base="${SERVER_URL_OPT:-${COOKIY_SERVER_URL:-}}"
  base="${base:-$DEFAULT_SERVER_URL}"
  API_ENDPOINT="${base%/}/mcp"
}

# --- JSON-RPC over curl ----------------------------------------------------

# POST JSON-RPC body to API_ENDPOINT; print response body on HTTP 200 only.
# On failure: print HTTP code, response snippet, and curl errors to stderr; return 1.
post_jsonrpc() {
  local payload="$1"
  local resp http body cerr
  cerr="$(mktemp -t cookiycurl.XXXXXX 2>/dev/null || mktemp)"
  resp="$(curl -sS --max-time "$API_CALL_TIMEOUT" -w '\n%{http_code}' \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$payload" \
    "$API_ENDPOINT" 2>"$cerr")" || {
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
    echo "HTTP $http — POST $API_ENDPOINT" >&2
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

# Read full JSON-RPC tools/call response on stdin; print CLI-facing result.
#
# Read path only (how we parse the JSON-RPC body — no network, no writes):
#   1. Success payload: .result.structuredContent.data only (no result.data fallback).
#   2. Success with null/missing data → print nothing.
#   3. Failure → full .result.structuredContent envelope when structuredContent.ok == false.
#
# content[0].text is ignored (agent/chat UIs only).
emit_tool_result() {
  local raw
  raw="$(cat)"
  echo "$raw" | jq -r '
    .result as $r
    | ($r.structuredContent // null) as $sc
    | (if $sc != null and ($sc | has("data")) then $sc.data else null end) as $payload
    | if $payload != null then
        $payload
      elif $sc != null and $sc.ok == false then
        $sc
      else
        empty
      end
  '
}


# invoke <tool_name> <arguments_json>
# Performs the 3-step JSON-RPC handshake: initialize, notify, tools/call
invoke() {
  command -v jq >/dev/null 2>&1 || die "cookiy.sh requires jq"
  local tool_name="$1"
  local args_json="${2:-\{\}}"

  # 1) initialize
  local init_resp
  init_resp="$(post_jsonrpc "{\"jsonrpc\":\"2.0\",\"id\":$(next_id),\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"cookiy-cli-sh\",\"version\":\"1.0.0\"}}}")" \
    || die "API initialize request failed"
  check_auth_error "$init_resp"
  check_rpc_error "$init_resp" || die "API initialize error"

  # 2) notifications/initialized
  post_jsonrpc '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null 2>&1 || true

  # 3) tools/call
  local call_resp
  call_resp="$(post_jsonrpc "{\"jsonrpc\":\"2.0\",\"id\":$(next_id),\"method\":\"tools/call\",\"params\":{\"name\":\"${tool_name}\",\"arguments\":${args_json}}}")" \
    || die "API tools/call request failed"
  check_auth_error "$call_resp"
  check_rpc_error "$call_resp" || exit 1

  local printable
  printable="$(echo "$call_resp" | emit_tool_result)"
  check_auth_error "$printable"
  echo "$printable"
  # Exit non-zero if tool returned ok:false. Guard with type == "object" so
  # plain-text results (from tools that set a custom contentText) do not
  # trigger jq errors or false positives.
  if echo "$printable" | jq -e 'type == "object" and .ok == false' >/dev/null 2>&1; then
    return 1
  fi
}

# Wait for report completion server-side, then return the share link.
wait_for_report_then_link() {
  local study_id="$1"
  local timeout_ms="${2:-300000}"
  # Server-side wait via cookiy_report_status (blocks until done or timeout)
  invoke cookiy_report_status "{\"study_id\":\"$(json_escape "$study_id")\",\"wait\":true,\"timeout_ms\":$timeout_ms}" > /dev/null || return 1
  # Report ready — fetch share link
  invoke cookiy_report_share_link_get "{\"study_id\":\"$(json_escape "$study_id")\"}"
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

# CLI string → JSON true/false (API expects boolean, not "true" strings)
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
          # amount_usd_cents → API param name amount_cents
          local json_key="$key"
          [[ "$key" == "amount_usd_cents" ]] && json_key="amount_cents"
          json+="\"$json_key\":$val" ;;
        survey_id)
          if [[ "$val" =~ ^[0-9]+$ ]]; then json+="\"$key\":$val"
          else json+="\"$key\":\"$(json_escape "$val")\""; fi ;;
        include_structure|include_raw|skip_synthetic_interview)
          json+="\"$key\":$(bool_json "$val")" ;;
        attachments)
          # JSON array passthrough — validated via jq when available.
          if command -v jq >/dev/null 2>&1; then
            echo "$val" | jq -e 'type == "array"' >/dev/null 2>&1 \
              || die "--attachments requires a JSON array, got: $val"
          else
            [[ "${val:0:1}" == "[" && "${val: -1}" == "]" ]] \
              || die "--attachments requires a JSON array, got: $val"
          fi
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

# Require key present and value not empty string (still allows numeric / non-string JSON values)
require_non_empty_string_value() {
  local key="$1" msg="$2"
  require_key "$key" "$msg"
  if echo "$BUILT_JSON" | grep -qE "\"$key\"[[:space:]]*:[[:space:]]*\"\"(,|})"; then
    die "$msg"
  fi
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
    Standalone shell client for the Cookiy AI platform.
    Run in a terminal: bash cookiy.sh <command>

    Long options use kebab-case; they are sent as snake_case JSON fields (e.g. --study-id → study_id).
    --wait passes server-side wait flags (no bash polling).
    --json merges extra JSON fields into the tool request, or provides the guide patch payload.
    Numeric sid for quant: --survey-id 12345 becomes JSON number when value is all digits.

GLOBAL OPTIONS
    --token <path>    Raw token file (default ~/.cookiy/token.txt; same as COOKIY_CREDENTIALS)
    --api-url <url>   Full JSON-RPC endpoint URL (overrides COOKIY_API_URL)

ENVIRONMENT
    COOKIY_CREDENTIALS       Path to raw token file
    COOKIY_API_URL           Full JSON-RPC endpoint URL
    COOKIY_API_RPC_TIMEOUT   Max seconds for API calls (default 600)
    COOKIY_SERVER_URL        API origin if endpoint URL not set

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
    Usage:   cookiy.sh study create --query <s> [--thinking <s>] [--attachments <json-array>] [--wait] [--timeout-ms <n>]
    Flags:   --query <string> (required)
             --thinking <string>
             --attachments <json-array>   JSON array, e.g. '[{"s3_key":"...","description":"..."}]'.
             --wait (server-side wait_for_guide — off by default; agents should poll study status instead)
             --timeout-ms <n> (only honored when --wait is set)

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
             cookiy.sh study interview playback url --study-id <uuid> [--interview-id <uuid>] [--cursor <s>]
             cookiy.sh study interview playback content --study-id <uuid> [--interview-id <uuid>] [--cursor <s>]
    Note:    list always includes synthetic interviews in results (not configurable via CLI).
             When --interview-id is omitted, playback returns a paginated list (default 20).
             Use --cursor to fetch subsequent pages.

study run-synthetic-user start — run synthetic user interviews
    Usage:   cookiy.sh study run-synthetic-user start --study-id <uuid> [--persona-count <n>] [--plain-text <s>] [--wait] [--timeout-ms <n>]
    Flags:   --study-id (required)
             --persona-count <integer>  Number of synthetic interviews to run
             --plain-text <string>  Participant persona / profile description (maps to API interviewee_persona)
             --wait (server-side wait — off by default; agents should poll status instead)
             --timeout-ms <n> (only honored when --wait is set)

recruit start — launch participant recruitment
    Usage:   cookiy.sh recruit start [--study-id <uuid>] [--survey-public-url <url>] [--confirmation-token <s>] [--plain-text <s>] [--incremental-participants <n>]
    Flags:   --study-id (qualitative — required for interview studies)
             --survey-public-url (quant — auto-sets recruit_mode=quant_survey; study-id optional)
    Output:  Full API envelope JSON (preview includes top-level sample_size, target_group, payment_quote, derived_languages).
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

quant status — LimeSurvey completion snapshot for a survey
    Usage:   cookiy.sh quant status --survey-id <n>
    Flags:   --survey-id <integer>   Numeric LimeSurvey sid from quant list
    Output:  JSON from cookiy_quant_survey_status (completed / incomplete / full response counts).
             Panel-side quant recruit progress is not exposed as a separate MCP tool on all
             servers; use cookiy_recruit_status with study_id when the study is linked.

quant report — survey report (structured JSON)
    Usage:   cookiy.sh quant report --survey-id <n>
    Flags:   --survey-id (required, numeric)
    Output:  JSON on stdout — aggregates (distributions/labels/percentages/numeric stats/
             completion funnel) + raw data (results_json, raw_participants).
             Raw data is auto-included; max_chars cap of 120K chars prevents context explosion.

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
             back-office UI, not a privilege level. Each Cookiy user lands as their
             own per-user LimeSurvey account, scoped to surveys they own. If the bridge
             is not configured on the server, the response sets configured=false and the
             affordance should be hidden by the calling client.

billing balance
    Usage:   cookiy.sh billing balance
    Output:  one plain-text line (balance_summary from API).

billing transactions — wallet ledger
    Usage:   cookiy.sh billing transactions [--limit <n>] [--cursor <iso8601>] [--study-id <uuid>] [--survey-id <sid>]
    Note:    MCP tool cookiy_billing_transactions (same JSON-RPC session as balance/checkout).

billing checkout
    Usage:   cookiy.sh billing checkout --amount-usd-cents <n>
    Flags:   USD integer cents (min 100); internally mapped to API amount_cents.

billing price-table
    Usage:   cookiy.sh billing price-table
    Output:  Current pricing table for all Cookiy operations (fetched from server).

BOOLEAN FLAGS (values: true | false | 1 | 0 | yes | no | on | off)
    --include-structure   --include-raw   --skip-synthetic-interview

save-token — store raw access token from browser sign-in
    Usage:   cookiy.sh save-token <access_token>
             cookiy.sh save-token '{"access_token":"eyJ..."}'
    Flow:    Verifies the token against the API, then writes raw token to --token path.
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
    --api-url|--mcp-url) API_URL_OPT="$2"; shift 2 ;;
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
resolve_api_endpoint

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
      # Only explicit --wait enables server-side wait. --timeout-ms alone is inert.
      if [[ "$ARG_WAIT" == "true" ]]; then
        json_set wait_for_guide true
      else
        json_del timeout_ms
      fi
      invoke cookiy_study_create "$BUILT_JSON"
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
          json_set include_simulation true
          invoke cookiy_interview_list "$BUILT_JSON"
          ;;
        playback)
          psub="${itail[0]:-}"
          ptail=("${itail[@]:1}")
          case "$psub" in
            url)
              build_json "study_id interview_id cursor" "${ptail[@]+"${ptail[@]}"}"
              require_key study_id "study interview playback url requires --study-id"
              json_set view '"url"'
              invoke cookiy_interview_playback_get "$BUILT_JSON"
              ;;
            content)
              build_json "study_id interview_id cursor" "${ptail[@]+"${ptail[@]}"}"
              require_key study_id "study interview playback content requires --study-id"
              json_set view '"transcript"'
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
          # Map --plain-text to API interviewee_persona
          if echo "$BUILT_JSON" | grep -q '"plain_text"'; then
            local pt_val
            pt_val="$(built_get plain_text)"
            json_del plain_text
            json_set interviewee_persona "\"$(json_escape "$pt_val")\""
          fi
          if [[ "$ARG_WAIT" == "true" ]]; then
            json_set wait true
          else
            json_del timeout_ms
          fi
          invoke cookiy_simulated_interview_generate "$BUILT_JSON"
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
            study_id_value="$(built_get study_id)"
            wait_for_report_then_link "$study_id_value"
          else
            invoke cookiy_report_generate "$BUILT_JSON"
          fi
          ;;
        content)
          build_json "study_id timeout_ms" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report content requires --study-id"
          # Only explicit --wait polls status first. --timeout-ms alone is inert.
          if [[ "$ARG_WAIT" == "true" ]]; then
            json_set wait true
            _rrc=0
            invoke cookiy_report_status "$BUILT_JSON" > /dev/null || _rrc=$?
            [[ $_rrc -eq 0 ]] || exit 1
          fi
          json_del timeout_ms
          invoke cookiy_report_content_get "$BUILT_JSON"
          ;;
        link)
          build_json "study_id" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report link requires --study-id"
          invoke cookiy_report_share_link_get "$BUILT_JSON"
          ;;
        wait)
          build_json "study_id timeout_ms" "${rrest[@]+"${rrest[@]}"}"
          require_key study_id "study report wait requires --study-id"
          study_id_value="$(built_get study_id)"
          timeout_ms_value="$(built_get_num timeout_ms 300000)"
          wait_for_report_then_link "$study_id_value" "$timeout_ms_value"
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
      # Default structure_presentation to json for CLI
      if ! echo "$BUILT_JSON" | grep -q '"structure_presentation"'; then
        json_set structure_presentation '"json"'
      fi
      invoke cookiy_quant_survey_detail "$BUILT_JSON"
      ;;
    update)
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
      merge_raw_json
      require_key survey_id "quant update requires --survey-id (numeric sid from quant list)"
      [[ -n "$ARG_JSON_RAW" ]] || die "quant update requires --json '<obj>'"
      invoke cookiy_quant_survey_patch "$BUILT_JSON"
      ;;
    status)
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
      require_key survey_id "quant status requires --survey-id (numeric sid from quant list)"
      invoke cookiy_quant_survey_status "$BUILT_JSON"
      ;;
    report)
      build_json "survey_id" "${qtail[@]+"${qtail[@]}"}"
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
      die "quant list|create|get|update|status|report|admin-link"
      ;;
  esac
  ;;

recruit)
  sub="${TAIL[0]:-}"
  rtail=("${TAIL[@]:1}")

  case "$sub" in
    start)
      build_json "study_id confirmation_token plain_text incremental_participants survey_public_url" "${rtail[@]+"${rtail[@]}"}"
      # --plain-text required on preview (step 1); step 2 only needs --confirmation-token
      if ! echo "$BUILT_JSON" | grep -q '"confirmation_token"'; then
        echo "$BUILT_JSON" | grep -q '"plain_text"' || die "recruit start: --plain-text is required"
      fi
      # Auto-detect quant mode when --survey-public-url is provided
      if echo "$BUILT_JSON" | grep -q '"survey_public_url"'; then
        json_set recruit_mode '"quant_survey"'
      fi
      # CLI policy: explicit reconfigure semantics (matches console UX). Live launch is enforced server-side on confirm.
      json_set force_reconfigure true
      invoke cookiy_recruit_create "$BUILT_JSON"
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
      invoke cookiy_balance_get '{}'
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
    transactions)
      build_json "limit cursor study_id survey_id" "${btail[@]+"${btail[@]}"}"
      invoke cookiy_billing_transactions "$BUILT_JSON"
      ;;
    *) die "billing balance|checkout|price-table|transactions" ;;
  esac
  ;;

*)
  die "Unknown command: $CMD
$(usage)"
  ;;

esac
