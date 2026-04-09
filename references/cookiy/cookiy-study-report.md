# Cookiy — Study Report

## CLI Commands

### report generate

Trigger report generation. Re-generates if a report already exists. Include `--wait` by default.

```
scripts/cookiy.sh study report generate --study-id <uuid> [--wait]
```

### report wait

Wait until the report has been generated.

```
scripts/cookiy.sh study report wait --study-id <uuid>
```

### report link

Get the public URL for the report.

```
scripts/cookiy.sh study report link --study-id <uuid>
```

### report content

Get the report as markdown.

```
scripts/cookiy.sh study report content --study-id <uuid>
```
