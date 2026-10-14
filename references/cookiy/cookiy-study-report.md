<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Study Report

## CLI Commands

### report generate

Trigger report generation. Re-generates if a report already exists. Synthetic interviews are included by default; only pass `--skip-synthetic-interview` if the user explicitly asks to exclude them.

```
cookiy study report generate --study-id <uuid> [--skip-synthetic-interview]
```

### report wait

Poll Study Activity until the report is ready, then print the report share-link JSON. The default
timeout is 5 minutes; `--timeout-ms` accepts a positive integer in milliseconds.

```
cookiy study report wait --study-id <uuid> [--timeout-ms <n>]
```

The report state comes from `sources.report.status`:

| State | Result |
|-------|--------|
| `report_generation_in_progress` | Continue polling |
| `report_ready` | Print the share-link response |
| `report_failed` | Exit with `GENERATION_FAILED` |
| `report_not_requested` | Exit with `REPORT_NOT_REQUESTED`; generate a report first |
| Missing or unknown | Exit with `UNEXPECTED_STATUS` |

Report-state errors exit nonzero and print JSON to stderr. On `WAIT_TIMEOUT`, `details` contains the latest
complete Study Activity. Continue waiting only when its `sources.report.status` is
`report_generation_in_progress`; run `wait` again with a new timeout. Do not call `generate` merely
because waiting timed out.

### report link

Get the public URL for the report.

```
cookiy study report link --study-id <uuid>
```

### report content

Get report content JSON; the Markdown is in its `markdown` field.

```
cookiy study report content --study-id <uuid>
```
