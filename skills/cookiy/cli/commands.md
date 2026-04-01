# Cookiy CLI reference

The `cookiy` command is shipped with the `cookiy-mcp` npm package
(`bin/cookiy.mjs`). In this repository you can also run:

- `./cookiy.sh` at the repo root, or
- `skills/cookiy/scripts/cookiy.sh`

They resolve to the same Node entrypoint.

This document is **user/agent facing**: it describes CLI verbs only. It does
not document IDE wiring or transport protocols.

---

## Environment and credentials

| Variable | Meaning |
| --- | --- |
| `COOKIY_CREDENTIALS` | Path to `credentials.json` (default: `~/.mcp/cookiy/credentials.json` on Unix-like systems) |
| `COOKIY_SERVER_URL` | Optional override of the API base URL (normally read from the credentials file) |
| `COOKIY_MCP_URL` | Full JSON-RPC MCP URL (e.g. `https://s-api.cookiy.ai/mcp`). Highest precedence over `mcp_url` in the file and over `API base + /mcp`. |

**Stable credential path:** by default the CLI reads and writes **`~/.mcp/cookiy/credentials.json`** (or `COOKIY_CREDENTIALS`). `cookiy login` merges new tokens into that file so paths do not change between login and daily commands.

**Obtaining credentials:**

1. **Terminal-only (recommended for the CLI):** `cookiy login` — browser OAuth, same PKCE flow as headless install; writes the file above. Optional: `cookiy login dev` (alias) or `--server-url`.
2. **IDE + skill install:** `npx cookiy-mcp --client <cursor|codex|…>` also writes credentials (and configures MCP). Headless: `npx cookiy-mcp --client manus -y` adds helper scripts under `~/.mcp/cookiy/<name>/` but the **CLI default path** remains `~/.mcp/cookiy/credentials.json` unless you set `COOKIY_CREDENTIALS`.

Resume: if OAuth is interrupted, run `cookiy login` again; it reuses `~/.mcp/cookiy/pending-oauth-cli.json` next to the credentials file.

The CLI reads `access_token` (and refreshes with `refresh_token` when the
server returns unauthorized) exactly like the generated shell helpers.

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

### `cookiy login [env-or-url]`

Interactive browser OAuth (PKCE). Writes **`access_token`**, **`refresh_token`**, `client_id`, `token_endpoint`, `server_url`, `mcp_url` into the credentials file (merges with existing JSON). Does **not** install IDE MCP configs.

Optional first argument: environment alias (`prod`, `dev`, `preview`, …) or a full API base URL — same rules as the installer.

### Agents (Cursor, etc.): auto-continue after login

`cookiy login` is **synchronous**: it does not return until the OAuth flow
completes and tokens are saved (or it exits with an error). So the user should
**not** need to send a second message such as “authorization done” if the agent
waits for the command to finish.

**Recommended pattern:** chain the next step so one terminal run covers setup
and verification:

```bash
cookiy login && cookiy doctor
```

**Avoid:**

- Running `login` in the **background** (the agent will think it finished too soon).
- **Short tool timeouts** on `login` — prefer several minutes if the runtime
  lets you set it; otherwise the process may be killed while the user is still
  in the browser.

**OAuth codes:** do not paste authorization codes or callback URLs into chat;
use the terminal window that is waiting on `cookiy login` only if manual paste
is required.

### `cookiy doctor`

Connectivity / introduce call with empty arguments.

### `cookiy help <topic>`

Topics include: `overview`, `study`, `ai_interview`, `guide`, `recruitment`,
`report`, `billing`, `quantitative` (aliases may work — server-side).

### Study

| Command | Notes |
| --- | --- |
| `cookiy study list` | Optional: `--query`, `--status`, `--limit`, `--cursor` |
| `cookiy study create` | Requires `--query`, `--language`; optional `--thinking`, `--attachments` as JSON via `--json` merge in future; `--wait` polls activity |
| `cookiy study get` | Requires `--study-id` |
| `cookiy study progress` | Alias: `cookiy study activity`. Requires `--study-id`; optional `--job-id`, `--include-debug` |
| `cookiy study show` | Requires `--study-id`; `--part record|progress|both` |
| `cookiy study guide status` | `--study-id` |
| `cookiy study guide get` | `--study-id` |
| `cookiy study guide impact` | `--study-id` and `--json` patch object |
| `cookiy study guide patch` | `--study-id`, `--base-revision`, `--idempotency-key`, `--json` patch; optional confirmation fields |
| `cookiy study guide upload` | `--content-type` plus `--image-data` or `--image-url`; `--study-id` if required by server |

**Kebab → API field:** `--study-id` maps to `study_id`, etc.

### Interview

| Command | Notes |
| --- | --- |
| `cookiy interview list` | `--study-id`, optional `--include-simulation`, `--cursor` |
| `cookiy interview playback` | `--study-id`, `--interview-id` |
| `cookiy interview simulate start` | Persona fields via flags or merge `--json`; `--wait` polls simulated job |
| `cookiy interview simulate status` | `--study-id`, `--job-id` |

### Recruitment

| Command | Notes |
| --- | --- |
| `cookiy recruit start` | Preview without `confirmation_token`; confirm with token. Additional fields may be passed via repeated flags or `--json` merge |
| `cookiy recruit status` | `--study-id` |

### Report

| Command | Notes |
| --- | --- |
| `cookiy report status` | `--study-id` |
| `cookiy report share-link` | `--study-id` |

### Quantitative

| Command | Maps to survey operations |
| --- | --- |
| `cookiy quant list` |  |
| `cookiy quant create` |  |
| `cookiy quant detail` | Include structure flags as in `tool-contract.md` |
| `cookiy quant patch` |  |
| `cookiy quant report` |  |
| `cookiy quant results` |  |
| `cookiy quant stats` |  |

Use `--json '{...}'` to supply fields not covered by flags (JSON keys use
`snake_case` as the server expects).

### Billing

| Command | Notes |
| --- | --- |
| `cookiy billing balance` | No required args |
| `cookiy billing checkout` | `--amount-usd-cents` (integer) or `--json` |

### Escape hatch: `cookiy tool call`

```
cookiy tool call <server_operation_name> --json '{"field": "value"}'
```

Use this when a field is not yet mapped to a subcommand. Operation names are
the **hosted public identifiers** (not repeated here to avoid drift); consult
the same source the Cookiy team publishes for integrators.

---

## Version

`cookiy --version` matches the `cookiy-mcp` package version string.
