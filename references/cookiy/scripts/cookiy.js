#!/usr/bin/env node
// Cookiy CLI — standalone Node.js client for Cookiy AI.
// Run in a terminal: node cookiy.js <command>
// Requires: Node.js 18+ (uses native fetch)
"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");

const VERSION = "1.21.0";
const DEFAULT_SERVER_URL = "https://s-api.cookiy.ai";
const DEFAULT_TOKEN_PATH = process.env.COOKIY_CREDENTIALS || path.join(os.homedir(), ".cookiy", "token.txt");
const API_CALL_TIMEOUT = parseInt(process.env.COOKIY_API_RPC_TIMEOUT || process.env.COOKIY_MCP_RPC_TIMEOUT || "600", 10);
const TIMEOUT = 120;

let RPC_ID = 0;
let TOKEN_PATH = DEFAULT_TOKEN_PATH;
let SERVER_URL_OPT = "";
let API_URL_OPT = "";
let ACCESS_TOKEN = "";
let API_ENDPOINT = "";

// Built JSON state (mirrors shell's BUILT_JSON, ARG_WAIT, ARG_JSON_RAW, ARG_POSITIONALS)
let BUILT_JSON = "{}";
let ARG_WAIT = "";
let ARG_JSON_RAW = "";
let ARG_POSITIONALS = [];

// --- helpers ---------------------------------------------------------------

function die(msg, code = 1) {
  console.error(msg);
  process.exit(code);
}

function nextId() {
  RPC_ID += 1;
  return RPC_ID;
}

function resolveServerBase() {
  const base = SERVER_URL_OPT || process.env.COOKIY_SERVER_URL || "";
  return base || DEFAULT_SERVER_URL;
}

function resolveLoginUrl() {
  return `${resolveServerBase()}/oauth/cli/start`;
}

function dieNoAccess() {
  const url = resolveLoginUrl();
  die(`Access denied — token is missing or expired.\nSign in:  ${url}`);
}

// JSON escape for embedding in JSON strings
function jsonEscape(str) {
  return str
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\t/g, "\\t")
    .replace(/\n/g, " ");
}

// Parse boolean CLI values
function boolJson(val) {
  const v = val.toLowerCase();
  if (["true", "1", "yes", "on"].includes(v)) return true;
  if (["false", "0", "no", "off"].includes(v)) return false;
  die(`Invalid boolean value: ${val} (use true or false)`);
}

// --- JSON builder (mirrors shell's build_json) -----------------------------

function jsonSet(key, val) {
  const obj = JSON.parse(BUILT_JSON);
  obj[key] = val;
  BUILT_JSON = JSON.stringify(obj);
}

function jsonDel(key) {
  const obj = JSON.parse(BUILT_JSON);
  delete obj[key];
  BUILT_JSON = JSON.stringify(obj);
}

function builtGet(key) {
  const obj = JSON.parse(BUILT_JSON);
  return obj[key];
}

function builtGetNum(key, defaultVal) {
  const obj = JSON.parse(BUILT_JSON);
  const val = obj[key];
  return typeof val === "number" ? val : defaultVal;
}

function buildJson(allowedKeys, args) {
  const allowed = allowedKeys.split(/\s+/).filter(Boolean);
  const pos = [];
  const obj = {};
  ARG_WAIT = "";
  ARG_JSON_RAW = "";
  ARG_POSITIONALS = [];

  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg.startsWith("--")) {
      let key = arg.slice(2).replace(/-/g, "_");
      let val;
      if (i + 1 < args.length && !args[i + 1].startsWith("--")) {
        val = args[i + 1];
        i += 2;
      } else {
        val = "true";
        i += 1;
      }

      // Special flags
      if (key === "wait") { ARG_WAIT = val; continue; }
      if (key === "json") { ARG_JSON_RAW = val; continue; }

      // Skip if not in allowed list
      if (!allowed.includes(key)) {
        console.error(`Warning: unknown flag --${key.replace(/_/g, "-")} (ignored)`);
        continue;
      }

      // Type handling
      const numericKeys = ["limit", "amount_usd_cents", "persona_count", "incremental_participants", "timeout_ms", "max_chars", "top_values_per_question", "sample_open_text_values"];
      const boolKeys = ["include_raw", "skip_synthetic_interview", "include_incomplete"];

      if (numericKeys.includes(key)) {
        if (!/^-?\d+$/.test(val)) die(`--${key.replace(/_/g, "-")} requires an integer, got: ${val}`);
        const jsonKey = key === "amount_usd_cents" ? "amount_cents" : key;
        obj[jsonKey] = parseInt(val, 10);
      } else if (key === "survey_id") {
        // Always string (per recent fix)
        obj[key] = val;
      } else if (boolKeys.includes(key)) {
        obj[key] = boolJson(val);
      } else if (key === "attachments") {
        try {
          const parsed = JSON.parse(val);
          if (!Array.isArray(parsed)) throw new Error("not array");
          obj[key] = parsed;
        } catch {
          die(`--attachments requires a JSON array, got: ${val}`);
        }
      } else {
        obj[key] = val;
      }
    } else {
      pos.push(arg);
      i += 1;
    }
  }

  BUILT_JSON = JSON.stringify(obj);
  ARG_POSITIONALS = pos;
}

function mergeRawJson() {
  if (!ARG_JSON_RAW || ARG_JSON_RAW === "{}") return;
  try {
    const base = JSON.parse(BUILT_JSON);
    const extra = JSON.parse(ARG_JSON_RAW);
    BUILT_JSON = JSON.stringify({ ...base, ...extra });
  } catch (e) {
    die(`Invalid --json value: ${e.message}`);
  }
}

function requireKey(key, msg) {
  const obj = JSON.parse(BUILT_JSON);
  if (!(key in obj)) die(msg);
}

function requireNonEmptyStringValue(key, msg) {
  requireKey(key, msg);
  const obj = JSON.parse(BUILT_JSON);
  if (obj[key] === "") die(msg);
}

function extractStudyId(resp) {
  return resp.study_id || resp.studyId || resp.id || null;
}

// --- auth error detection --------------------------------------------------

function checkAuthError(body) {
  if (typeof body !== "object" || body === null) return;
  const sc = body.status_code;
  if (sc === 401 || sc === 403) dieNoAccess();
  const code = body.error?.code;
  if (["UNAUTHORIZED", "FORBIDDEN", "AUTH_REQUIRED"].includes(code)) dieNoAccess();
}

// --- token & credentials ---------------------------------------------------

function loadCredentials() {
  if (!fs.existsSync(TOKEN_PATH)) dieNoAccess();
  ACCESS_TOKEN = fs.readFileSync(TOKEN_PATH, "utf8").replace(/\r?\n/g, "").trim();
  if (!ACCESS_TOKEN) dieNoAccess();
}

function resolveApiEndpoint() {
  if (API_URL_OPT) { API_ENDPOINT = API_URL_OPT; return; }
  const envUrl = process.env.COOKIY_API_URL || process.env.COOKIY_MCP_URL || "";
  if (envUrl) { API_ENDPOINT = envUrl; return; }
  const base = SERVER_URL_OPT || process.env.COOKIY_SERVER_URL || DEFAULT_SERVER_URL;
  API_ENDPOINT = `${base.replace(/\/$/, "")}/mcp`;
}

// --- JSON-RPC over fetch ---------------------------------------------------

async function postJsonRpc(payload, timeout = API_CALL_TIMEOUT) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout * 1000);

  try {
    const res = await fetch(API_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "Authorization": `Bearer ${ACCESS_TOKEN}`,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    const http = res.status;
    const body = await res.text();

    if (http === 401 || http === 403) dieNoAccess();
    if (http < 200 || http >= 300) {
      console.error(`HTTP ${http} — POST ${API_ENDPOINT}`);
      if (body.trim()) console.error(body.slice(0, 4000));
      return null;
    }

    try {
      return JSON.parse(body);
    } catch {
      return body;
    }
  } catch (e) {
    clearTimeout(timeoutId);
    if (e.name === "AbortError") {
      console.error(`Request timeout (${timeout}s)`);
    } else {
      console.error(`fetch: ${e.message}`);
    }
    return null;
  }
}

function checkRpcError(resp) {
  if (!resp || typeof resp !== "object") return false;
  const errMsg = resp.error?.message;
  if (errMsg) {
    const errData = resp.error?.data;
    if (errData) {
      console.error(`${errMsg}: ${errData}`);
    } else {
      console.error(errMsg);
    }
    return true;
  }
  return false;
}

function emitToolResult(resp) {
  if (!resp || typeof resp !== "object") return null;
  const r = resp.result;
  if (!r) return null;

  const sc = r.structuredContent;
  let payload = null;

  if (sc && "data" in sc) {
    payload = sc.data;
  }

  if (payload !== null) {
    return payload;
  } else if (sc && sc.ok === false) {
    return sc;
  }
  return null;
}

async function invoke(toolName, argsJson = "{}") {
  const args = typeof argsJson === "string" ? JSON.parse(argsJson) : argsJson;

  // 1) initialize
  const initResp = await postJsonRpc({
    jsonrpc: "2.0",
    id: nextId(),
    method: "initialize",
    params: {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "cookiy-cli-js", version: "1.0.0" },
    },
  }, TIMEOUT);

  if (!initResp) die("API initialize request failed");
  checkAuthError(initResp);
  if (checkRpcError(initResp)) die("API initialize error");

  // 2) notifications/initialized
  await postJsonRpc({ jsonrpc: "2.0", method: "notifications/initialized" }, TIMEOUT).catch(() => {});

  // 3) tools/call
  const callResp = await postJsonRpc({
    jsonrpc: "2.0",
    id: nextId(),
    method: "tools/call",
    params: { name: toolName, arguments: args },
  });

  if (!callResp) die("API tools/call request failed");
  checkAuthError(callResp);
  if (checkRpcError(callResp)) process.exit(1);

  const printable = emitToolResult(callResp);
  checkAuthError(printable);

  if (printable !== null) {
    console.log(typeof printable === "string" ? printable : JSON.stringify(printable, null, 2));
  }

  // Exit non-zero if tool returned ok:false
  if (printable && typeof printable === "object" && printable.ok === false) {
    return false;
  }
  return true;
}

// --- save-token command ----------------------------------------------------

async function runSaveToken(input) {
  input = input.trim();
  if (!input) die("Usage: cookiy.js save-token <access_token_or_json>");

  let at = "";
  try {
    const parsed = JSON.parse(input);
    if (parsed.access_token) at = parsed.access_token;
  } catch {
    at = input;
  }
  if (!at) die("Could not find access_token in input.");

  const rawServer = resolveServerBase();
  let apiEnd = API_URL_OPT || process.env.COOKIY_API_URL || process.env.COOKIY_MCP_URL || "";
  if (!apiEnd) apiEnd = `${rawServer.replace(/\/$/, "")}/mcp`;

  // Verify token works
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT * 1000);

  try {
    const res = await fetch(apiEnd, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "Authorization": `Bearer ${at}`,
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2025-03-26",
          capabilities: {},
          clientInfo: { name: "cookiy-cli-js", version: "1.0.0" },
        },
      }),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

    const http = res.status;
    const body = await res.text();

    if (http !== 200) {
      die(`Token verify HTTP ${http} — token may be invalid or expired. Sign in again at: ${resolveLoginUrl()}`);
    }

    try {
      const parsed = JSON.parse(body);
      if (parsed.error) {
        die(`Token verify error: ${JSON.stringify(parsed.error)}`);
      }
    } catch {}
  } catch (e) {
    clearTimeout(timeoutId);
    die(`Token verify failed (${e.message}). Check your network and try again.`);
  }

  // Save token
  const dir = path.dirname(TOKEN_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(TOKEN_PATH, at, { mode: 0o600 });

  console.error(`Token verified and saved to ${TOKEN_PATH}`);
}

// --- wait for report then link ---------------------------------------------

async function waitForReportThenLink(studyId, timeoutMs = 300000) {
  // Server-side wait via cookiy_report_status
  const statusResp = await postJsonRpc({
    jsonrpc: "2.0",
    id: nextId(),
    method: "tools/call",
    params: {
      name: "cookiy_report_status",
      arguments: { study_id: studyId, wait: true, timeout_ms: timeoutMs },
    },
  });

  if (!statusResp || checkRpcError(statusResp)) return false;

  // Fetch share link
  return invoke("cookiy_report_share_link_get", JSON.stringify({ study_id: studyId }));
}

// --- help / usage ----------------------------------------------------------

function getUsageText() {
  return `Cookiy CLI v${VERSION}  (standalone Node.js client)

Run in a terminal: node cookiy.js <command>

Usage:
  cookiy.js [--token <path>] [--api-url <url>] <command> ...

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
  quant list|create|get|update|status|report|raw-response  Quantitative survey management (keyed by survey-id)
  billing balance|checkout|price-table|transactions

Examples:
  cookiy.js save-token eyJhbGciOi...
  cookiy.js help commands
  cookiy.js study list --limit 10
  cookiy.js study create --query "..."  --wait
  cookiy.js study report generate --study-id 123 --skip-synthetic-interview --wait
  cookiy.js study report wait --study-id 123 --timeout-ms 300000
  cookiy.js billing transactions --limit 50`;
}

function printUsage() {
  console.log(getUsageText());
}

function printCliCommandsReference() {
  console.log(`NAME
    cookiy.js — standalone Cookiy AI CLI (Node.js, zero dependencies)

SYNOPSIS
    cookiy.js [GLOBAL OPTION ...] <command> [ARG ...]

VERSION
    ${VERSION}

DESCRIPTION
    Standalone Node.js client for the Cookiy AI platform.
    Run in a terminal: node cookiy.js <command>

    Long options use kebab-case; they are sent as snake_case JSON fields (e.g. --study-id → study_id).
    --wait passes server-side wait flags (no polling).
    --json merges extra JSON fields into the tool request, or provides the guide patch payload.
    Numeric sid for quant: --survey-id 12345 becomes JSON string.

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
    Usage:   cookiy.js help
    Note:    Prints this reference. No credentials needed.

study list — list studies
    Usage:   cookiy.js study list [--limit <n>] [--cursor <s>]
    Flags:   --limit <integer>   --cursor <string>

study create — create study from natural language
    Usage:   cookiy.js study create --query <s> [--thinking <s>] [--attachments <json-array>] [--wait] [--timeout-ms <n>]
    Flags:   --query <string> (required)
             --thinking <string>
             --attachments <json-array>   JSON array, e.g. '[{"s3_key":"...","description":"..."}]'.
             --wait (server-side wait_for_guide — off by default; agents should poll study status instead)
             --timeout-ms <n> (only honored when --wait is set)

study status — study record and activity
    Usage:   cookiy.js study status --study-id <uuid>
    Flags:   --study-id (required)
    Calls cookiy_activity_get which server-side merges the study record and activity summary.

study guide get
    Usage:   cookiy.js study guide get --study-id <uuid>
    Flags:   --study-id (required)

study guide update — apply patch to discussion guide
    Usage:   cookiy.js study guide update --study-id <uuid> --base-revision <s> --idempotency-key <s> [--change-message <s>] --json '<patch>'
    Flags:   --study-id (required)   --base-revision (required)   --idempotency-key (required)   --json (required)
             --change-message

study upload — attach media (image upload)
    Usage:   cookiy.js study upload --content-type <s> (--image-data <s> | --image-url <s>)
    Flags:   --content-type (required)   --image-data | --image-url (one required)

study interview list | playback url|content
    Usage:   cookiy.js study interview list --study-id <uuid> [--cursor <s>]
             cookiy.js study interview playback url --study-id <uuid> [--interview-id <uuid>] [--cursor <s>]
             cookiy.js study interview playback content --study-id <uuid> [--interview-id <uuid>] [--cursor <s>]
    Note:    list always includes synthetic interviews in results (not configurable via CLI).
             When --interview-id is omitted, playback returns a paginated list (default 20).
             Use --cursor to fetch subsequent pages.

study run-synthetic-user start — run synthetic user interviews
    Usage:   cookiy.js study run-synthetic-user start --study-id <uuid> [--persona-count <n>] [--plain-text <s>] [--wait] [--timeout-ms <n>]
    Flags:   --study-id (required)
             --persona-count <integer>  Number of synthetic interviews to run
             --plain-text <string>  Participant persona / profile description (maps to API interviewee_persona)
             --wait (server-side wait — off by default; agents should poll status instead)
             --timeout-ms <n> (only honored when --wait is set)

recruit start — launch participant recruitment
    Usage:   cookiy.js recruit start [--study-id <uuid>] [--survey-public-url <url>] [--confirmation-token <s>] [--plain-text <s>] [--incremental-participants <n>]
    Flags:   --study-id (qualitative — required for interview studies)
             --survey-public-url (quant — auto-sets recruit_mode=quant_survey; study-id optional)
    Output:  Full API envelope JSON (preview includes top-level sample_size, target_group, payment_quote, derived_languages).
    Note:    incremental_participants is auto-capped to remaining sample size capacity. If below current channel target, treated as incremental ("recruit N more").

study report generate | content | link
    Usage:   cookiy.js study report generate --study-id <uuid> [--skip-synthetic-interview] [--wait]
             cookiy.js study report content --study-id <uuid> [--wait] [--timeout-ms <n>]
             cookiy.js study report link --study-id <uuid>
    generate with --wait polls report link every 10s until status=completed (or failed/timeout).

quant list — list surveys
    Usage:   cookiy.js quant list
    Note:    Lists all surveys visible to the operator (sid, title, active, language).

quant create — create survey (multi-language)
    Usage:   cookiy.js quant create --json '<obj>'
    Flags:   --json (required): JSON with survey_title, languages[], groups[], quotas[], etc.
    Multi-lang: Set "languages":["en","zh","ja"] and use per-language maps for text fields.
                Respondents can switch language on the survey page.
    Schema:  See cookiy-quant-create-schema.md for full field reference.

quant get — survey detail
    Usage:   cookiy.js quant get --survey-id <n>
    Flags:   --survey-id (required, numeric)

quant update — patch survey
    Usage:   cookiy.js quant update --survey-id <n> --json '<obj>'
    Flags:   --survey-id (required, numeric)
             --json (required): JSON with survey, groups, questions, quotas_create, quotas_update, etc.

quant status — combined survey + panel recruitment status
    Usage:   cookiy.js quant status --survey-id <n>
    Flags:   --survey-id <integer>   Numeric LimeSurvey sid from \`quant list\`
    Output:  Single JSON envelope wrapping both sides:
             { survey_id, survey: { completed_responses, incomplete_responses, full_responses },
               recruit: { total_bought, total_completed } }.
             When no recruit project exists yet (recruit not started), the recruit block
             reports zeros instead of erroring.

quant report — survey report (structured JSON)
    Usage:   cookiy.js quant report --survey-id <n>
    Flags:   --survey-id (required, numeric)
    Output:  JSON on stdout — aggregates (distributions/labels/percentages/numeric stats/
             completion funnel) + raw data (results_json, raw_participants).
             Raw data is auto-included; max_chars cap of 120K chars prevents context explosion.

quant raw-response — raw survey responses as CSV
    Usage:   cookiy.js quant raw-response --survey-id <n> [--include-incomplete]
    Flags:   --survey-id (required, numeric)
             --include-incomplete (bool; default false — exclude incomplete responses)
    Output:  Raw CSV text on stdout (no JSON envelope). Output can be large —
             redirect to a file, e.g. \`cookiy.js quant raw-response --survey-id 12345 > responses.csv\`.

billing balance
    Usage:   cookiy.js billing balance
    Output:  one plain-text line (balance_summary from API).

billing transactions — wallet ledger
    Usage:   cookiy.js billing transactions [--limit <n>] [--cursor <iso8601>] [--study-id <uuid>] [--survey-id <sid>]
    Output:  pretty-printed JSON array (agent-friendly; same fields as GET /v1/billing/transactions).
    Note:    MCP tool cookiy_billing_transactions (same JSON-RPC session as balance/checkout).

billing checkout
    Usage:   cookiy.js billing checkout --amount-usd-cents <n>
    Flags:   USD integer cents (min 100); internally mapped to API amount_cents.

billing price-table
    Usage:   cookiy.js billing price-table
    Output:  Current pricing table for all Cookiy operations (fetched from server).

BOOLEAN FLAGS (values: true | false | 1 | 0 | yes | no | on | off)
    --include-raw   --skip-synthetic-interview   --include-incomplete

save-token — store raw access token from browser sign-in
    Usage:   cookiy.js save-token <access_token>
             cookiy.js save-token '{"access_token":"eyJ..."}'
    Flow:    Verifies the token against the API, then writes raw token to --token path.
    Get token: open the sign-in page at {server}/oauth/cli/start, log in, copy the token.

FILES
    Default token file: ~/.cookiy/token.txt`);
}

// --- commands --------------------------------------------------------------

async function cmdStudy(sub, args) {
  switch (sub) {
    case "list": {
      buildJson("limit cursor", args);
      return invoke("cookiy_study_list", BUILT_JSON);
    }
    case "status": {
      buildJson("study_id", args);
      requireKey("study_id", "study status requires --study-id");
      return invoke("cookiy_activity_get", BUILT_JSON);
    }
    case "create": {
      buildJson("query thinking attachments timeout_ms", args);
      requireKey("query", "study create requires --query");
      if (ARG_WAIT === "true") {
        jsonSet("wait_for_guide", true);
      } else {
        jsonDel("timeout_ms");
      }
      return invoke("cookiy_study_create", BUILT_JSON);
    }
    case "upload": {
      buildJson("image_data image_url content_type", args);
      requireKey("content_type", "study upload requires --content-type");
      return invoke("cookiy_media_upload", BUILT_JSON);
    }
    case "guide": {
      const gcmd = args[0] || "";
      const gtail = args.slice(1);
      switch (gcmd) {
        case "get": {
          buildJson("study_id", gtail);
          requireKey("study_id", "study guide get requires --study-id");
          return invoke("cookiy_guide_get", BUILT_JSON);
        }
        case "update": {
          buildJson("study_id base_revision idempotency_key change_message", gtail);
          requireKey("study_id", "study guide update requires --study-id");
          requireKey("base_revision", "study guide update requires --base-revision");
          requireKey("idempotency_key", "study guide update requires --idempotency-key");
          if (!ARG_JSON_RAW) die("study guide update requires --json '<patch>'");
          const obj = JSON.parse(BUILT_JSON);
          obj.patch = JSON.parse(ARG_JSON_RAW);
          return invoke("cookiy_guide_patch", JSON.stringify(obj));
        }
        default:
          die(`Unknown: study guide ${gcmd || "(none)"}`);
      }
      break;
    }
    case "interview": {
      const isub = args[0] || "";
      const itail = args.slice(1);
      switch (isub) {
        case "list": {
          buildJson("study_id cursor", itail);
          requireKey("study_id", "study interview list requires --study-id");
          jsonSet("include_simulation", true);
          return invoke("cookiy_interview_list", BUILT_JSON);
        }
        case "playback": {
          const psub = itail[0] || "";
          const ptail = itail.slice(1);
          switch (psub) {
            case "url": {
              buildJson("study_id interview_id cursor", ptail);
              requireKey("study_id", "study interview playback url requires --study-id");
              jsonSet("view", "url");
              return invoke("cookiy_interview_playback_get", BUILT_JSON);
            }
            case "content": {
              buildJson("study_id interview_id cursor", ptail);
              requireKey("study_id", "study interview playback content requires --study-id");
              jsonSet("view", "transcript");
              return invoke("cookiy_interview_playback_get", BUILT_JSON);
            }
            default:
              die("study interview playback url|content --study-id <uuid> [--interview-id <uuid>]");
          }
          break;
        }
        default:
          die(`Unknown study interview subcommand: ${isub || "(none)"}`);
      }
      break;
    }
    case "run-synthetic-user": {
      const ssub = args[0] || "";
      const srest = args.slice(1);
      switch (ssub) {
        case "start": {
          buildJson("study_id persona_count plain_text timeout_ms", srest);
          requireKey("study_id", "study run-synthetic-user start requires --study-id");
          if (ARG_WAIT === "true") {
            jsonSet("wait", true);
          } else {
            jsonDel("timeout_ms");
          }
          return invoke("cookiy_simulated_interview_generate", BUILT_JSON);
        }
        default:
          die("study run-synthetic-user start");
      }
      break;
    }
    case "report": {
      const rsub = args[0] || "";
      const rrest = args.slice(1);
      switch (rsub) {
        case "generate": {
          buildJson("study_id skip_synthetic_interview", rrest);
          requireKey("study_id", "study report generate requires --study-id");
          if (ARG_WAIT === "true") {
            const ok = await invoke("cookiy_report_generate", BUILT_JSON);
            if (!ok) process.exit(1);
            const studyIdValue = builtGet("study_id");
            return waitForReportThenLink(studyIdValue);
          } else {
            return invoke("cookiy_report_generate", BUILT_JSON);
          }
        }
        case "content": {
          buildJson("study_id timeout_ms", rrest);
          requireKey("study_id", "study report content requires --study-id");
          if (ARG_WAIT === "true") {
            jsonSet("wait", true);
            const statusResp = await postJsonRpc({
              jsonrpc: "2.0",
              id: nextId(),
              method: "tools/call",
              params: {
                name: "cookiy_report_status",
                arguments: JSON.parse(BUILT_JSON),
              },
            });
            if (!statusResp || checkRpcError(statusResp)) process.exit(1);
          }
          jsonDel("timeout_ms");
          return invoke("cookiy_report_content_get", BUILT_JSON);
        }
        case "link": {
          buildJson("study_id", rrest);
          requireKey("study_id", "study report link requires --study-id");
          return invoke("cookiy_report_share_link_get", BUILT_JSON);
        }
        case "wait": {
          buildJson("study_id timeout_ms", rrest);
          requireKey("study_id", "study report wait requires --study-id");
          const studyIdValue = builtGet("study_id");
          const timeoutMsValue = builtGetNum("timeout_ms", 300000);
          return waitForReportThenLink(studyIdValue, timeoutMsValue);
        }
        default:
          die("study report generate|content|link|wait");
      }
      break;
    }
    default:
      die(`Unknown study subcommand: ${sub || "(none)"}
Available: list, create, status, upload, guide, interview, run-synthetic-user, report`);
  }
}

async function cmdQuant(sub, args) {
  switch (sub) {
    case "list": {
      buildJson("", args);
      return invoke("cookiy_quant_survey_list", BUILT_JSON);
    }
    case "create": {
      buildJson("", args);
      mergeRawJson();
      if (!ARG_JSON_RAW) die("quant create requires --json '<obj>'");
      return invoke("cookiy_quant_survey_create", BUILT_JSON);
    }
    case "get": {
      buildJson("survey_id", args);
      requireKey("survey_id", "quant get requires --survey-id (numeric sid from quant list)");
      return invoke("cookiy_quant_survey_detail", BUILT_JSON);
    }
    case "update": {
      buildJson("survey_id", args);
      mergeRawJson();
      requireKey("survey_id", "quant update requires --survey-id (numeric sid from quant list)");
      if (!ARG_JSON_RAW) die("quant update requires --json '<obj>'");
      return invoke("cookiy_quant_survey_patch", BUILT_JSON);
    }
    case "status": {
      buildJson("survey_id", args);
      requireKey("survey_id", "quant status requires --survey-id (numeric sid from quant list)");
      return invoke("cookiy_quant_status", BUILT_JSON);
    }
    case "report": {
      buildJson("survey_id", args);
      requireKey("survey_id", "quant report requires --survey-id (numeric sid from quant list)");
      return invoke("cookiy_quant_survey_report", BUILT_JSON);
    }
    case "raw-response":
    case "raw_response": {
      buildJson("survey_id include_incomplete", args);
      requireKey("survey_id", "quant raw-response requires --survey-id (numeric sid from quant list)");

      // Need to get the result and extract raw CSV
      const callResp = await postJsonRpc({
        jsonrpc: "2.0",
        id: nextId(),
        method: "tools/call",
        params: {
          name: "cookiy_quant_survey_raw_responses",
          arguments: JSON.parse(BUILT_JSON),
        },
      });

      if (!callResp) die("API tools/call request failed");
      checkAuthError(callResp);
      if (checkRpcError(callResp)) process.exit(1);

      const result = emitToolResult(callResp);
      if (result && result.raw_results && result.raw_results.raw) {
        console.log(result.raw_results.raw);
      }
      return true;
    }
    default:
      die("quant list|create|get|update|status|report|raw-response");
  }
}

async function cmdRecruit(sub, args) {
  switch (sub) {
    case "start": {
      buildJson("study_id confirmation_token plain_text incremental_participants survey_public_url", args);
      const obj = JSON.parse(BUILT_JSON);

      // --plain-text required on preview (step 1); step 2 only needs --confirmation-token
      if (!("confirmation_token" in obj)) {
        if (!("plain_text" in obj)) die("recruit start: --plain-text is required");
      }

      // Auto-detect quant mode
      if ("survey_public_url" in obj) {
        jsonSet("recruit_mode", "quant_survey");
      }

      // CLI policy: explicit reconfigure semantics
      jsonSet("force_reconfigure", true);

      return invoke("cookiy_recruit_create", BUILT_JSON);
    }
    default:
      die("recruit start");
  }
}

async function cmdBilling(sub, args) {
  switch (sub) {
    case "balance": {
      if (args.length > 0) die("billing balance takes no arguments");
      return invoke("cookiy_balance_get", "{}");
    }
    case "checkout": {
      buildJson("amount_usd_cents", args);
      requireKey("amount_cents", "billing checkout requires --amount-usd-cents <integer>");
      return invoke("cookiy_billing_cash_checkout", BUILT_JSON);
    }
    case "price-table": {
      if (args.length > 0) die("billing price-table takes no arguments");
      return invoke("cookiy_billing_price_table", "{}");
    }
    case "transactions": {
      buildJson("limit cursor study_id survey_id", args);
      return invoke("cookiy_billing_transactions", BUILT_JSON);
    }
    default:
      die("billing balance|checkout|price-table|transactions");
  }
}

// --- main ------------------------------------------------------------------

async function main() {
  const rawArgs = process.argv.slice(2);
  const args = [];

  // Parse global options
  let i = 0;
  while (i < rawArgs.length) {
    const arg = rawArgs[i];
    if (arg === "--server-url" && i + 1 < rawArgs.length) {
      SERVER_URL_OPT = rawArgs[i + 1];
      i += 2;
    } else if ((arg === "--api-url" || arg === "--mcp-url") && i + 1 < rawArgs.length) {
      API_URL_OPT = rawArgs[i + 1];
      i += 2;
    } else if ((arg === "--token" || arg === "--credentials") && i + 1 < rawArgs.length) {
      TOKEN_PATH = rawArgs[i + 1];
      i += 2;
    } else if (arg === "-h" || arg === "--help") {
      printUsage();
      process.exit(0);
    } else {
      args.push(arg);
      i += 1;
    }
  }

  if (args.length === 0) {
    printUsage();
    process.exit(0);
  }

  const cmd = args[0];
  const tail = args.slice(1);

  // Version
  if (cmd === "-v" || cmd === "--version") {
    console.log(VERSION);
    process.exit(0);
  }

  // Help (no credentials needed)
  if (cmd === "help") {
    printCliCommandsReference();
    process.exit(0);
  }

  // save-token (no prior credentials required)
  if (cmd === "save-token") {
    if (tail.length < 1) die("Usage: cookiy.js save-token <access_token_or_json>");
    await runSaveToken(tail.join(" "));
    process.exit(0);
  }

  // All commands below need credentials
  loadCredentials();
  resolveApiEndpoint();

  // Re-initialize for JSON-RPC
  // (initialize is called inside invoke, so we need fresh RPC_ID)

  switch (cmd) {
    case "study": {
      const sub = tail[0] || "";
      const stail = tail.slice(1);
      const ok = await cmdStudy(sub, stail);
      process.exit(ok ? 0 : 1);
      break;
    }
    case "quant": {
      const sub = tail[0] || "";
      const qtail = tail.slice(1);
      const ok = await cmdQuant(sub, qtail);
      process.exit(ok ? 0 : 1);
      break;
    }
    case "recruit": {
      const sub = tail[0] || "";
      const rtail = tail.slice(1);
      const ok = await cmdRecruit(sub, rtail);
      process.exit(ok ? 0 : 1);
      break;
    }
    case "billing": {
      const sub = tail[0] || "";
      const btail = tail.slice(1);
      const ok = await cmdBilling(sub, btail);
      process.exit(ok ? 0 : 1);
      break;
    }
    default: {
      // Shell does: die "Unknown command: $CMD\n$(usage)" which prints both to stderr
      const usageText = getUsageText();
      die(`Unknown command: ${cmd}\n${usageText}`);
    }
  }
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
