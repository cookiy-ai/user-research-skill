<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Study Report

## CLI Commands

### report generate

Trigger report generation. Re-generates if a report already exists. Synthetic interviews are included by default; only pass `--skip-synthetic-interview` if the user explicitly asks to exclude them.

```
cookiy study report generate --study-id <uuid> [--skip-synthetic-interview]
```

### report wait

Wait until the report has been generated.

```
cookiy study report wait --study-id <uuid>
```

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

Generation completion is not a content-quality check. Compare the report with the included
interviews: verify actual sample counts, simulation provenance, methodology, and supporting
quotes. Synthetic material must be identified as AI simulation and cannot establish real-user
or market findings. Preserve conditional statements and distinguish self-reported expectations
from measured effects. Report unsupported claims as quality issues; do not silently regenerate
a paid report to replace the evidence.
