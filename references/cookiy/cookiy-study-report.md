# Cookiy — Study Report Operations

Commands for retrieving study reports.

---

## CLI Commands

### report wait

Wait until the study report has been generated.

```
scripts/cookiy.sh study report wait --study-id <uuid>
```

### report link

Get the public URL for the study report.

```
scripts/cookiy.sh study report link --study-id <uuid>
```

### report content

Get the markdown content of the study report directly.

```
scripts/cookiy.sh study report content --study-id <uuid>
```
