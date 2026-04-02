#!/usr/bin/env bash
# Cookiy CLI — pure shell wrapper over hosted JSON-RPC using curl.
# Requires: bash, curl, jq, grep, sed.
set -euo pipefail

VERSION="1.11.0"
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

usage() {
  cat <<EOF
Cookiy CLI v${VERSION}  (shell)

Usage:
  cookiy.sh [--credentials <path>] [--mcp-url <url>] <command> ...

Global options:
  --mcp-url        Full JSON-RPC URL (overrides COOKIY_MCP_URL and credentials mcp_url)
  --credentials    Path to credentials.json (default: ~/.mcp/cookiy/credentials.json)

Environment:
  COOKIY_CREDENTIALS   Path to credentials.json
  COOKIY_MCP_URL       Full MCP URL (production default: https://s-api.cookiy.ai/mcp)

Commands:
  save-token <token>          Save an access token to credentials.json (validates first)
  doctor                      Connectivity check
  help [commands|cli|<topic>] Local CLI manual (no topic / commands / cli) or server workflow help
  study list|create|status|guide ...
  interview list|playback|simulate ...
  recruit start
  report link|content
  quant list|create|get|update|report
  billing balance|checkout

Examples:
  cookiy.sh save-token eyJhbGciOi...
  cookiy.sh doctor
  cookiy.sh study list --limit 10
  cookiy.sh study create --query "..." --language zh
EOF
}

# --- login URL + unified auth-failure handler ------------------------------

resolve_server_base() {
  local base="${SERVER_URL_OPT:-${COOKIY_SERVER_URL:-}}"
  if [[ -z "$base" && -f "$CREDENTIALS_PATH" ]]; then
    base="$(json_get server_url < "$CREDENTIALS_PATH" || true)"
  fi
  echo "${base:-$DEFAULT_SERVER_URL}"
}

resolve_login_url() {
  echo "$(resolve_server_base)/oauth/cli/start"
}

die_no_access() {
  local url
  url="$(resolve_login_url)"
  die "Access denied — token is missing or expired.
Sign in:  $url
Then run:  ./cookiy.sh save-token <your_access_token>"
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
  if [[ -z "$mcp_end" && -f "$CREDENTIALS_PATH" ]]; then
    mcp_end="$(json_get mcp_url < "$CREDENTIALS_PATH" || true)"
  fi
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

  mkdir -p "$(dirname "$CREDENTIALS_PATH")"
  local prev_json now
  prev_json='{}'
  if [[ -f "$CREDENTIALS_PATH" ]]; then
    prev_json="$(jq -c '.' "$CREDENTIALS_PATH" 2>/dev/null || echo '{}')"
  fi
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  jq -n \
    --argjson prev "$prev_json" \
    --arg base "$raw_server" \
    --arg mcp "$mcp_end" \
    --arg at "$at" \
    --arg now "$now" \
    '($prev)
      + {
          server_url: $base,
          mcp_url: $mcp,
          access_token: $at,
          token_type: "Bearer",
          updated_at: $now,
          created_at: ($prev.created_at // $now)
        }' > "$CREDENTIALS_PATH"

  echo "Token verified and saved to $CREDENTIALS_PATH" >&2
  echo "Next: ./cookiy.sh doctor" >&2
}

# --- credentials & URL resolution ------------------------------------------

CREDENTIALS_PATH="$DEFAULT_CREDENTIALS_PATH"
SERVER_URL_OPT=""
MCP_URL_OPT=""
ACCESS_TOKEN=""
MCP_ENDPOINT=""

load_credentials() {
  [[ -f "$CREDENTIALS_PATH" ]] || die_no_access
  ACCESS_TOKEN="$(cred_val access_token | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/\r$//')"
  [[ -n "$ACCESS_TOKEN" ]] || die_no_access
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

# POST JSON-RPC body to MCP_ENDPOINT; print response body on HTTP 200 only.
# On failure: print HTTP code, response snippet, and curl errors to stderr; return 1.
post_jsonrpc() {
  local payload="$1"
  local resp http body cerr
  cerr="$(mktemp -t cookiycurl.XXXXXX 2>/dev/null || mktemp)"
  resp="$(curl -sS --max-time "$TIMEOUT" -w '\n%{http_code}' \
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

check_rpc_error() {
  local resp="$1"
  local err_msg
  err_msg="$(echo "$resp" | jq -r '.error.message // empty' 2>/dev/null)"
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
# Numeric keys: limit, amount_usd_cents, persona_count, target_participants, max_price_per_interview
# survey_id: digits only → JSON number (LimeSurvey sid); otherwise string
# Boolean keys: include_simulation, include_structure, auto_launch, force_reconfigure, wait, auto_generate_personas, recruit_reconfigure_confirmed
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
        limit|amount_usd_cents|persona_count|target_participants|max_price_per_interview)
          json+="\"$key\":$val" ;;
        survey_id)
          if [[ "$val" =~ ^[0-9]+$ ]]; then json+="\"$key\":$val"
          else json+="\"$key\":\"$(json_escape "$val")\""; fi ;;
        include_simulation|include_structure|auto_launch|force_reconfigure|auto_generate_personas|recruit_reconfigure_confirmed)
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
    Wrapper-only: --wait (poll after some commands), --json (merge extra fields; not sent as a literal key).
    Numeric sid for quant: --survey-id 12345 becomes JSON number when value is all digits.

GLOBAL OPTIONS
    --credentials <path>   Credentials JSON (default: ~/.mcp/cookiy/credentials.json)
    --mcp-url <url>        Full JSON-RPC URL (overrides COOKIY_MCP_URL / file)

ENVIRONMENT
    COOKIY_CREDENTIALS     Path to credentials.json
    COOKIY_MCP_URL         Full MCP JSON-RPC URL

DOCUMENTATION
    skills/cookiy/cli/commands.md

COMMANDS

doctor — connectivity / introduce (filtered: removes tools list)
    Usage:   cookiy.sh doctor
    Flags:   (none)
    Note:    Requires credentials.

help — this text or server topics (prints key_points when available)
    Usage:   cookiy.sh help
             cookiy.sh help commands
             cookiy.sh help cli
             cookiy.sh help <topic>
    Flags:   (none)
    Note:    Empty, "commands", or "cli" prints this reference offline. <topic> calls the
             hosted help tool and needs credentials (e.g. overview, quantitative).

study list — list studies (TSV: studyId, projectName, state)
    Usage:   cookiy.sh study list [--query <s>] [--status <s>] [--limit <n>] [--cursor <s>]
    Flags:   --query <string>   --status <string>   --limit <integer>   --cursor <string>

study create — create study from natural language (prints studyId)
    Usage:   cookiy.sh study create --query <s> --language <s> [--thinking <s>] [--attachments <s>] [--wait]
    Flags:   --query <string> (required)   --language <string> (required)
             --thinking <string>   --attachments <string>   --wait (poll activity)

study status — study record + activity summary (filtered JSON)
    Usage:   cookiy.sh study status --study-id <uuid>
    Flags:   --study-id (required)

study guide get — full discussion guide
    Usage:   cookiy.sh study guide get --study-id <uuid>
    Flags:   --study-id (required)

study guide update — apply guide patch (prints {revision, applied} or {error})
    Usage:   cookiy.sh study guide update --study-id <uuid> --base-revision <s> --idempotency-key <s> --json '<patch>' [--change-message <s>] [--recruit-reconfigure-confirmed <bool>]
    Flags:   --study-id (required)   --base-revision (required)   --idempotency-key (required)   --json (required)
             --change-message   --recruit-reconfigure-confirmed <bool>

study guide upload — attach media (prints s3_key)
    Usage:   cookiy.sh study guide upload --content-type <s> (--image-data <s> | --image-url <s>) [--study-id <uuid>]
    Flags:   --content-type (required)   --image-data | --image-url (one required)   --study-id

interview list (TSV: interview_id, latest_completed_interview_id, status)
    Usage:   cookiy.sh interview list --study-id <uuid> [--include-simulation <bool>] [--cursor <s>]
    Flags:   --study-id (required)   --include-simulation   --cursor

interview playback
    Usage:   cookiy.sh interview playback --study-id <uuid> --interview-id <uuid>
    Flags:   --study-id (required)   --interview-id (required, non-empty)

interview simulate start (prints job_id)
    Usage:   cookiy.sh interview simulate start --study-id <uuid> [--auto-generate-personas <bool>] [--persona-count <n>] [--interviewee-persona <s>] [--json '<obj>'] [--wait]
    Flags:   --study-id (required)   --auto-generate-personas   --persona-count   --interviewee-persona   --json   --wait

recruit start (prints {preview_only, confirmation_token, status_message})
    Usage:   cookiy.sh recruit start --study-id <uuid> [--confirmation-token <s>] [--plain-text <s>] [--target-participants <n>] [--execution-duration <n>] [--max-price-per-interview <n>] [--channel-name <s>] [--auto-launch <bool>] [--force-reconfigure <bool>] [--recruit-mode <s>] [--survey-public-url <s>] [--json '<obj>']
    Flags:   --study-id (required); others optional; --json merges extra fields
    Note:    First call returns confirmation_token; re-run with --confirmation-token to confirm.

report link (prints share_url)
    Usage:   cookiy.sh report link --study-id <uuid>
    Flags:   --study-id (required)

report content (not yet implemented)
    Note:    Pending MCP endpoint.

quant list (TSV: sid, title)
    Usage:   cookiy.sh quant list [--survey-id <sid>] [--study-id <uuid>] [--query <s>] [--cursor <s>] [--limit <n>] [--json '<obj>']

quant create (prints survey_id)
    Usage:   cookiy.sh quant create --json '<survey_spec>'

quant get | update | report
    Usage:   cookiy.sh quant get --survey-id <sid> [--json '<obj>']
             cookiy.sh quant update | report  (same pattern)
    Flags:   --survey-id (required, numeric sid); other filters optional
    Output:  get → filtered JSON; update → {survey_updated, questions_updated};
             report → {summary_raw, response_row_count, quota_summaries}

billing balance
    Usage:   cookiy.sh billing balance
    Output:  one plain-text line (balance_summary).

billing checkout
    Usage:   cookiy.sh billing checkout --amount-usd-cents <n> [--json '<obj>']
    Flags:   USD integer cents (min 100).

BOOLEAN FLAGS (values: true | false | 1 | 0 | yes | no | on | off)
    --include-simulation   --include-structure
    --auto-launch   --force-reconfigure   --auto-generate-personas   --recruit-reconfigure-confirmed

save-token — store an access token from browser sign-in
    Usage:   cookiy.sh save-token <access_token>
             cookiy.sh save-token '{"access_token":"eyJ..."}'
    Flow:    Verifies the token against MCP, then writes credentials.json.
    Get token: open the sign-in page at {server}/oauth/cli/start, log in, copy the token.
    Needs:   jq, curl

FILES
    Default credentials: ~/.mcp/cookiy/credentials.json
EOF
}

# === Parse global options ==================================================

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    # Undocumented in usage/help; for internal API base override only.
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

# Local CLI manual: no credentials
if [[ "$CMD" == "help" ]]; then
  htopic="${TAIL[0]:-}"
  if [[ -z "$htopic" || "$htopic" == "commands" || "$htopic" == "cli" ]]; then
    print_cli_commands_reference
    exit 0
  fi
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

doctor)
  invoke cookiy_introduce '{}' \
    | jq 'del(.data.presentation_hint) | .data.what_you_can_do |= map(del(.tools))'
  ;;

help)
  topic="${TAIL[*]:-}"
  [[ -n "$topic" ]] || die "Usage: cookiy help <topic> (or: cookiy help commands)"
  invoke cookiy_help "{\"topic\":\"$(json_escape "$topic")\"}" \
    | jq -r 'if .data.key_points then .data.key_points[] else .data end'
  ;;

study)
  sub="${TAIL[0]:-}"
  stail=("${TAIL[@]:1}")

  case "$sub" in
    list)
      build_json "query status limit cursor" "${stail[@]+"${stail[@]}"}"
      invoke cookiy_study_list "$BUILT_JSON" \
        | jq -r '.data.list[]? | [.studyId, .projectName, .state] | @tsv'
      ;;
    create)
      build_json "query language thinking attachments" "${stail[@]+"${stail[@]}"}"
      require_key query "study create requires --query"
      require_key language "study create requires --language"
      result="$(invoke cookiy_study_create "$BUILT_JSON")"
      echo "$result" | jq -r '.data.studyId // empty'
      if [[ "$ARG_WAIT" == "true" ]]; then
        sid="$(echo "$result" | jq -r '.data.studyId // empty')"
        [[ -n "$sid" ]] || die "Could not find study_id for --wait"
        poll_activity "$sid"
      fi
      ;;
    status)
      build_json "study_id" "${stail[@]+"${stail[@]}"}"
      require_key study_id "study status requires --study-id"
      local_study_id="$(built_get study_id)"
      {
        invoke cookiy_study_get "{\"study_id\":\"$local_study_id\"}"
        invoke cookiy_activity_get "{\"study_id\":\"$local_study_id\"}"
      } | jq -s '{
        record: (
          .[0].data
          | del(.authoritative_status_sources, .recruit_snapshot, .report_snapshot, .next_recommended_tools)
          | if .workflow_summary != null then .workflow_summary |= del(.authoritative_truth_order) else . end
        ),
        activity_status: .[1].data.status_message
      }'
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
          build_json "study_id base_revision idempotency_key change_message recruit_reconfigure_confirmed" "${gtail[@]+"${gtail[@]}"}"
          require_key study_id "study guide update requires --study-id"
          require_key base_revision "study guide update requires --base-revision"
          require_key idempotency_key "study guide update requires --idempotency-key"
          [[ -n "$ARG_JSON_RAW" ]] || die "study guide update requires --json"
          BUILT_JSON="${BUILT_JSON%\}},\"patch\":$ARG_JSON_RAW}"
          invoke cookiy_guide_patch "$BUILT_JSON" \
            | jq 'if .ok then {revision: .data.revision, applied: .data.applied} else {error: .error} end'
          ;;
        upload)
          build_json "study_id image_data image_url content_type" "${gtail[@]+"${gtail[@]}"}"
          require_key content_type "study guide upload requires --content-type"
          invoke cookiy_media_upload "$BUILT_JSON" \
            | jq -r '.data.s3_key // empty'
          ;;
        *) die "Unknown: study guide ${gcmd:-} (use: get|update|upload)" ;;
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
      invoke cookiy_interview_list "$BUILT_JSON" \
        | jq -r '.data.interviews[]? | [.interview_id, .latest_completed_interview_id, .status] | @tsv'
      ;;
    playback)
      build_json "study_id interview_id" "${itail[@]+"${itail[@]}"}"
      require_key study_id "interview playback requires --study-id"
      require_non_empty_string_value interview_id "interview playback requires --interview-id (set from interview list output)"
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
          echo "$result" | jq -r '.data.job_id // empty'
          if [[ "$ARG_WAIT" == "true" ]]; then
            local_sid="$(built_get study_id)"
            job_id="$(echo "$result" | jq -r '.data.job_id // empty')"
            [[ -n "$job_id" ]] || die "Could not find job_id for --wait"
            poll_sim_status "$local_sid" "$job_id"
          fi
          ;;
        *) die "interview simulate start" ;;
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
      invoke cookiy_recruit_create "$BUILT_JSON" \
        | jq '{preview_only:.data.preview_only, confirmation_token:.data.confirmation_token, status_message:.data.status_message}'
      ;;
    *) die "recruit start" ;;
  esac
  ;;

report)
  sub="${TAIL[0]:-}"
  rtail=("${TAIL[@]:1}")

  case "$sub" in
    link)
      build_json "study_id" "${rtail[@]+"${rtail[@]}"}"
      require_key study_id "report link requires --study-id"
      invoke cookiy_report_share_link_get "$BUILT_JSON" \
        | jq -r '.data.share_url // empty'
      ;;
    content)
      die "report content is not yet implemented (pending MCP endpoint)"
      ;;
    *) die "report link|content" ;;
  esac
  ;;

quant)
  sub="${TAIL[0]:-}"
  qtail=("${TAIL[@]:1}")

  case "$sub" in
    list)    tool=cookiy_quant_survey_list ;;
    create)  tool=cookiy_quant_survey_create ;;
    get)     tool=cookiy_quant_survey_detail ;;
    update)  tool=cookiy_quant_survey_patch ;;
    report)  tool=cookiy_quant_survey_report ;;
    *)       die "quant list|create|get|update|report" ;;
  esac
  build_json "survey_id study_id include_structure structure_presentation query cursor limit" "${qtail[@]+"${qtail[@]}"}"
  merge_raw_json
  case "$sub" in
    get|update|report)
      require_key survey_id "quant $sub requires --survey-id (numeric sid from quant list)"
      if echo "$BUILT_JSON" | grep -qE "\"survey_id\"[[:space:]]*:[[:space:]]*\"\"(,|})"; then
        die "quant $sub requires non-empty --survey-id (e.g. export SURVEY_ID=487898)"
      fi
      ;;
  esac
  result="$(invoke "$tool" "$BUILT_JSON")"
  case "$sub" in
    list)    echo "$result" | jq -r '.data.surveys[]? | [(.sid // .survey_id // .id | tostring), .title] | @tsv' ;;
    create)  echo "$result" | jq -r '.data.survey_id // empty' ;;
    get)     echo "$result" | jq 'if (.data | type) == "object" then .data |= del(.next_recommended_tools) else . end' ;;
    update)  echo "$result" | jq '{survey_updated:.data.survey_updated, questions_updated:.data.questions_updated}' ;;
    report)  echo "$result" | jq '.data | {summary_raw, response_row_count, quota_summaries}' ;;
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
      BUILT_JSON="$(echo "$BUILT_JSON" | jq -c 'if has("amount_usd_cents") then .amount_cents = .amount_usd_cents | del(.amount_usd_cents) else . end')"
      require_key amount_cents "billing checkout requires --amount-usd-cents <integer>"
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
