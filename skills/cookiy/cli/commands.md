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

**Obtaining credentials:** use the existing Cookiy bootstrap for your host
environment. The headless / sandbox flow (`npx cookiy-mcp --client manus -y`)
writes `credentials.json` plus helper scripts under `~/.mcp/cookiy/`. Other
clients use the same installer with a different `--client` value.

The CLI reads `access_token` (and refreshes with `refresh_token` when the
server returns unauthorized) exactly like the generated shell helpers.

---

## Global flags

These flags may appear **before** the subcommand:

| Flag | Purpose |
| --- | --- |
| `--server-url <url>` | Force a specific Cookiy API base URL |
| `--credentials <path>` | Use an alternate credentials file |

---

## Output

By default the CLI prints `structuredContent` as JSON when present, otherwise
the full tool result JSON. For automation, pipe to `jq` as needed.

---

## Command tree

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
