# Cookiy — Interview Retrieval Operations

Commands for fetching interview details for both real participant and synthetic user interviews.

---

## CLI Commands

### study interview list

List all interviews for a study.

```
scripts/cookiy.sh study interview list --study-id <uuid> [--cursor <s>]
```

### study interview playback url

Get the playback URL of a specific interview. If `--interview-id` is not provided, returns playback
URLs for all interviews under the study.

```
scripts/cookiy.sh study interview playback url --study-id <uuid> [--interview-id <uuid>]
```

### study interview playback content

Get the content (transcript) of a specific interview. If `--interview-id` is not provided, returns
content for all interviews under the study.

```
scripts/cookiy.sh study interview playback content --study-id <uuid> [--interview-id <uuid>]
```
