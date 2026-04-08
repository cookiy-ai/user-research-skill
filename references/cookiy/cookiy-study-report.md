# Cookiy — Study Report Operations

Commands for manual study report generation and retrieval.

---

## CLI Commands

Both command surfaces are supported:

- `scripts/cookiy.sh study report ...`
- `scripts/cookiy.sh report ...`

They are equivalent. The top-level `report ...` form is a shortcut.

### report generate

Trigger a new manual report generation request.

The request returns immediately unless `--wait` is used.

```
scripts/cookiy.sh study report generate --study-id <uuid>
scripts/cookiy.sh report generate --study-id <uuid>
```

Optional flags:

- `--skip-synthetic-interview`
  - Exclude simulated / synthetic interviews from the generated report
- `--wait`
  - Poll `report link` every 10 seconds until the latest request reaches `completed`
- `--timeout-ms <n>`
  - Optional timeout for `--wait`
- `--reason <text>`
  - Optional generation reason

Examples:

```
scripts/cookiy.sh report generate --study-id <uuid> --skip-synthetic-interview
scripts/cookiy.sh report generate --study-id <uuid> --wait
```

### report link

Get the public share URL for the latest completed manual report generation request.

If the latest request is still running, the command returns status metadata instead of a ready link.

```
scripts/cookiy.sh study report link --study-id <uuid>
scripts/cookiy.sh report link --study-id <uuid>
```

### report content

Get the report content for the latest completed manual report generation request.

For MCP transcript reports, this returns the original markdown body directly.

If the latest request is still running, the command returns status metadata instead of report content.

```
scripts/cookiy.sh study report content --study-id <uuid>
scripts/cookiy.sh report content --study-id <uuid>
```

Optional flags:

- `--wait`
  - First poll `report status` until the latest request reaches a terminal state
- `--timeout-ms <n>`
  - Optional timeout for `--wait`

---

## Status Semantics

The latest manual generation request is reported with these states:

- `pending`
  - The request has been created and queued
- `generating`
  - The report consumer is actively generating the report
- `completed`
  - The latest generated report is ready for `link` and `content`
- `failed`
  - The latest request failed; trigger `report generate` again to retry

Important behavior:

- `report status`, `report content`, and `report link` only follow the latest manual generation request
- They do not automatically trigger report generation
- They do not fall back to older reports while a newer request is pending or generating
- Older share links remain valid, but `report link` always targets the latest completed manual report request
