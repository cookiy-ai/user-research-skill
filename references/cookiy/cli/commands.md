# Cookiy CLI reference

**Canonical CLI for this skill:** [`scripts/cookiy.sh`](../scripts/cookiy.sh) — **bash and curl only** (no npm/Node). From the repository root you can run `./cookiy.sh`, which `exec`s the same script.

This document is **user/agent facing**: it describes CLI verbs only. It does
not document IDE wiring or transport protocols.

**同事复制即测**（含默认 `STUDY_ID`、完整命令块）：[`colleague-smoke-commands.md`](colleague-smoke-commands.md).

---

## Environment and credentials

| Variable | Meaning |
| --- | --- |
| `COOKIY_CREDENTIALS` | Path to `credentials.json` (default: `~/.mcp/cookiy/credentials.json` on Unix-like systems) |
| `COOKIY_SERVER_URL` | Optional override of the API base URL (normally read from the credentials file) |
| `COOKIY_MCP_URL` | Full JSON-RPC MCP URL (e.g. `https://s-api.cookiy.ai/mcp`). Highest precedence over `mcp_url` in the file and over `API base + /mcp`. |

**Stable credential path:** by default the CLI reads **`~/.mcp/cookiy/credentials.json`** (or `COOKIY_CREDENTIALS`).

### Browser sign-in (recommended — no Node.js or MCP)

`cookiy.sh` has **no** interactive `login` subcommand. For **skill + shell CLI**
only, obtain tokens from the hosted sign-in page in a normal browser:

| Environment | Sign-in URL (path is always `/login`) |
| --- | --- |
| Production (short-link app) | `https://s.cookiy.ai/login` |
| Example non-production | `https://dev.cookiy.ai/login` — use the web origin your Cookiy deployment documents |

1. Open the URL, complete bot check and **Google** or **Facebook** sign-in (or
   registration, including invite code if your workspace requires it).
2. On success, the page shows an **`access_token`** and a **sample
   `credentials.json`** (with `mcp_url` / `server_url` placeholders). Copy
   them into your credentials file on the machine where you run `./cookiy.sh`.
3. **Do not** paste tokens or OAuth **authorization codes** into agent chat.
4. Run `./cookiy.sh doctor` to verify connectivity.

**Required in `credentials.json` for API calls:**

- `access_token` (required)
- `mcp_url` and/or `server_url` (required in practice — e.g. production MCP
  JSON-RPC is `https://s-api.cookiy.ai/mcp` and API base `https://s-api.cookiy.ai`,
  unless your environment uses different hosts)

**Refresh tokens:** the browser sign-in flow currently issues an **access token**
only. When it expires, open `/login` again and update `credentials.json`, or
use an optional Node-based installer path (below).

**Optional (Node.js — MCP / `cookiy-mcp` installer):** if you install via
`npx cookiy-mcp` or an IDE marketplace flow, you may instead complete OAuth
through that tool (local callback). That path is **not** required for
`./cookiy.sh`.

The shell CLI speaks the same hosted JSON-RPC `tools/call` protocol Cookiy
exposes at your `mcp_url` / `--mcp-url`.

---

## Global flags

These flags may appear **before** the subcommand:

| Flag | Purpose |
| --- | --- |
| `--server-url <url>` | Force a specific Cookiy API base URL |
| `--mcp-url <url>` | Full MCP JSON-RPC URL for this process (overrides `COOKIY_MCP_URL` / file) |
| `--credentials <path>` | Use an alternate credentials file |

---

## Output

By default the CLI prints `structuredContent` as JSON when present, otherwise
the full tool result JSON. For automation, pipe to `jq` as needed.

---

## Command tree

All examples below use `./cookiy.sh`; substitute `skills/cookiy/scripts/cookiy.sh` if you prefer a non-root path.

### `./cookiy.sh doctor`

Connectivity / introduce call with empty arguments.

### `./cookiy.sh help` — local CLI manual (no credentials)

Prints a **POSIX/man-style** reference: **NAME / SYNOPSIS / GLOBAL OPTIONS / COMMANDS**, with each command showing **Usage** and **Flags** (similar to common `--help` from Cobra / git-style tools). Same output for:

```bash
./cookiy.sh help
./cookiy.sh help commands
./cookiy.sh help cli
```

### `./cookiy.sh help <topic>` — server workflow help (needs credentials)

Topics include: `overview`, `study`, `ai_interview`, `guide`, `recruitment`,
`report`, `billing`, `quantitative` (aliases may work — server-side).

### Study

| Command | Notes |
| --- | --- |
| `./cookiy.sh study list` | Optional: `--query`, `--status`, `--limit`, `--cursor` |
| `./cookiy.sh study create` | Requires `--query`, `--language`; optional `--thinking`, `--attachments` as JSON via `--json` merge in future; `--wait` polls activity |
| `./cookiy.sh study get` | Requires `--study-id` |
| `./cookiy.sh study progress` | Alias: `./cookiy.sh study activity`. Requires `--study-id`; optional `--job-id`, `--include-debug` |
| `./cookiy.sh study show` | Requires `--study-id`; `--part record|progress|both` |
| `./cookiy.sh study guide status` | `--study-id` |
| `./cookiy.sh study guide get` | `--study-id` |
| `./cookiy.sh study guide impact` | `--study-id` and `--json` patch object |
| `./cookiy.sh study guide patch` | `--study-id`, `--base-revision`, `--idempotency-key`, `--json` patch; optional confirmation fields |
| `./cookiy.sh study guide upload` | `--content-type` plus `--image-data` or `--image-url`; `--study-id` if required by server |

**Kebab → API field:** `--study-id` maps to `study_id`, etc.

### Interview

| Command | Notes |
| --- | --- |
| `./cookiy.sh interview list` | `--study-id`, optional `--include-simulation`, `--cursor` |
| `./cookiy.sh interview playback` | `--study-id`, `--interview-id` |
| `./cookiy.sh interview simulate start` | Persona fields via flags or merge `--json`; `--wait` polls simulated job |
| `./cookiy.sh interview simulate status` | `--study-id`, `--job-id` |

### Recruitment

| Command | Notes |
| --- | --- |
| `./cookiy.sh recruit start` | Preview without `confirmation_token`; confirm with token. Additional fields may be passed via repeated flags or `--json` merge |
| `./cookiy.sh recruit status` | `--study-id` |

### Report

| Command | Notes |
| --- | --- |
| `./cookiy.sh report status` | `--study-id` |
| `./cookiy.sh report share-link` | `--study-id` |

### Quantitative

| Command | Maps to survey operations |
| --- | --- |
| `./cookiy.sh quant list` |  |
| `./cookiy.sh quant create` |  |
| `./cookiy.sh quant detail` | Include structure flags as in `tool-contract.md` |
| `./cookiy.sh quant patch` |  |
| `./cookiy.sh quant report` |  |
| `./cookiy.sh quant results` |  |
| `./cookiy.sh quant stats` |  |

Use `--json '{...}'` to supply fields not covered by flags (JSON keys use
`snake_case` as the server expects).

### Billing

| Command | Notes |
| --- | --- |
| `./cookiy.sh billing balance` | No required args |
| `./cookiy.sh billing checkout` | `--amount-usd-cents` (integer) or `--json` |

### Escape hatch: `./cookiy.sh tool call`

```
./cookiy.sh tool call <server_operation_name> --json '{"field": "value"}'
```

Use this when a field is not yet mapped to a subcommand. Operation names are
the **hosted public identifiers** (not repeated here to avoid drift); consult
the same source the Cookiy team publishes for integrators.

---

## Version

`./cookiy.sh --version` prints the version string embedded in [`scripts/cookiy.sh`](../scripts/cookiy.sh) (`VERSION=` near the top of that file).
