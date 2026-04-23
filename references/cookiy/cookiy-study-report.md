# Cookiy — Study Report

## CLI Commands

### report generate

Trigger report generation. Re-generates if a report already exists. Synthetic interviews are included by default; only pass `--skip-synthetic-interview` if the user explicitly asks to exclude them.

```
cookiy study report generate --study-id <uuid> [--skip-synthetic-interview]
```

### report wait

Block until report generation finishes (polls `study status` every 15s), then print the report
share link. Exits non-zero on timeout.

```
cookiy study report wait --study-id <uuid> [--timeout-ms <n>]
```

`--timeout-ms` defaults to `300000` (5 minutes).

### report link

Get the public URL for the report.

```
cookiy study report link --study-id <uuid>
```

### report content

Get the report as markdown.

```
cookiy study report content --study-id <uuid>
```
