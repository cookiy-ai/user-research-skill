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
| `COOKIY_MCP_URL` | Optional full JSON-RPC MCP URL (e.g. `https://s-api.cookiy.ai/mcp`). Overrides `mcp_url` in the file when set for a given run. |
| `COOKIY_LOGIN_PROBE_TIMEOUT` | Optional seconds for MCP `initialize` probe at start of `login` (default **30**). |
| `COOKIY_SERVER_URL` | Optional API base URL for **`login`** (and MCP resolution when no `mcp_url`). Avoids typing `--server-url` if you export this once per shell. |

**Credential file:** the CLI reads **`~/.mcp/cookiy/credentials.json`** unless you pass `--credentials` or set `COOKIY_CREDENTIALS`.

**`login` without long flags** (paths/hosts only via environment):

```bash
export COOKIY_CREDENTIALS="$HOME/.mcp/cookiy/alternate-credentials.json"
export COOKIY_SERVER_URL='https://<api-host>'   # omit for production default in script
./cookiy.sh login
```

### Sign-in: `login` (single path)

**Flow:** First, if `credentials.json` already exists and `access_token` can complete an MCP **`initialize`** against the MCP URL resolved for this run (file + optional `--mcp-url` / `COOKIY_MCP_URL`), **`login` exits immediately** — no browser — and you can go straight to `doctor` / `study` / etc. If the file is missing, the token is empty, or MCP returns an error, the script **opens the OAuth (PKCE + dynamic registration) flow**, and **merges the new tokens into** `credentials.json`.

Requires **bash**, **curl**, **jq**, **openssl**. If the pasted redirect URL has a URL-encoded `code=`, **python3** is used to decode it. Optional: **`COOKIY_LOGIN_PROBE_TIMEOUT`** (seconds, default **30**) caps how long the pre-check `initialize` may take.

**Default command** (production API / MCP unless you override with env or flags):

```bash
./cookiy.sh --credentials "$HOME/.mcp/cookiy/credentials.json" login
```

Callback is fixed to `http://127.0.0.1:18247/callback` — after sign-in, copy the **full address bar URL** from that page (even if the browser shows a connection error), paste it into the terminal, press Enter.

Then verify:

```bash
./cookiy.sh doctor
```

(Use the same `--credentials` path as for `login` if it is not the default.)

**Required in `credentials.json` after `login`:** `access_token`, `server_url`, `mcp_url`, and other fields the script saves. Do **not** paste tokens or OAuth authorization codes into agent chat.

**Refresh / retry:** when the token expires or MCP rejects it, run the same `login` again — the pre-check fails and the browser flow runs. A `refresh_token` is stored when the server returns one.

The shell CLI uses the hosted JSON-RPC `tools/call` protocol at your `mcp_url` / `COOKIY_MCP_URL` / `--mcp-url`.

---

## Global flags

These flags may appear **before** the subcommand:

| Flag | Purpose |
| --- | --- |
| `--credentials <path>` | Credentials file path |
| `--mcp-url <url>` | Full MCP JSON-RPC URL for this process (overrides `COOKIY_MCP_URL` / file) |

---

## Output

By default the CLI prints `structuredContent` as JSON when present, otherwise
the full tool result JSON. For automation, pipe to `jq` as needed.

---

## Command tree

All examples below use `./cookiy.sh`; substitute `skills/cookiy/scripts/cookiy.sh` if you prefer a non-root path.

### `./cookiy.sh login`

OAuth sign-in for **production**; writes `credentials.json`. Does not require an existing file. Takes **no** subcommand arguments (only global flags such as `--credentials`).

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
| `./cookiy.sh billing checkout` | `--amount-cents` (USD integer cents, min 100) or `--json` |

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

---

## Related

- Tool contracts and errors: [`references/tool-contract.md`](../references/tool-contract.md)
- Command tree (Chinese notes): [`cli/cli-command-tree.md`](cli-command-tree.md)
