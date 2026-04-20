# Cookiy — Study Report

## CLI Commands

### report generate

Trigger report generation. Re-generates if a report already exists. Synthetic interviews are included by default; only pass `--skip-synthetic-interview` if the user explicitly asks to exclude them.

```
npx cookiy-cli study report generate --study-id <uuid> [--skip-synthetic-interview]
```

### report wait

Wait until the report has been generated.

```
npx cookiy-cli study report wait --study-id <uuid>
```

### report link

Get the public URL for the report.

```
npx cookiy-cli study report link --study-id <uuid>
```

### report content

Get the report as markdown.

```
npx cookiy-cli study report content --study-id <uuid>
```
