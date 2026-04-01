# Cookiy CLI reference

**Canonical CLI for this skill:** [`scripts/cookiy.sh`](../scripts/cookiy.sh) — **bash and curl only** (no Node.js). From the repository root you can run `./cookiy.sh`, which `exec`s the same script.

This document is **user/agent facing**: it describes CLI verbs only. It does
not document IDE wiring or transport protocols.

---

## Environment and credentials

| Variable | Meaning |
| --- | --- |
| `COOKIY_CREDENTIALS` | Path to `credentials.json` (default: `~/.mcp/cookiy/credentials.json` on Unix-like systems) |
| `COOKIY_SERVER_URL` | Optional override of the API base URL (normally read from the credentials file) |
| `COOKIY_MCP_URL` | Full JSON-RPC MCP URL (e.g. `https://s-api.cookiy.ai/mcp`). Highest precedence over `mcp_url` in the file and over `API base + /mcp`. |

**Stable credential path:** by default the CLI reads **`~/.mcp/cookiy/credentials.json`** (or `COOKIY_CREDENTIALS`).

**Obtaining credentials (shell CLI):** `cookiy.sh` does **not** implement an interactive `login` subcommand. You need a JSON file that includes at least:

- `access_token` (required to call the API)
- `refresh_token` (recommended — used when the access token expires)
- `server_url` and/or `mcp_url` (recommended — otherwise use `--server-url` / `--mcp-url` / `COOKIY_MCP_URL`)

Provision this file through your team’s Cookiy onboarding (for example completing account link in the IDE once MCP is configured, or copying a file from an environment that already authenticated). After the file exists, run `./cookiy.sh doctor` to verify connectivity.

The shell CLI sends the same JSON-RPC `tools/call` envelope as MCP clients; token refresh behavior depends on the hosted service and whether `refresh_token` is present in the file.

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

### `./cookiy.sh help <topic>`

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
