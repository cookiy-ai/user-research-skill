<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Interview Retrieval Operations

Commands for fetching interview details for both real participant and synthetic user interviews.

---

## CLI Commands

### study interview list

List all interviews for a study.

```
cookiy study interview list --study-id <uuid> [--cursor <s>]
```

### study interview playback url

Get the playback URL of a specific interview. If `--interview-id` is not provided, returns playback
URLs for all interviews under the study.

The URL opens an interview detail page; obtaining it does not verify media playback.
Both real and synthetic interviews have transcripts. Synthetic interviews have no audio or
video recording, so media playback is not applicable. For a real interview, separately verify
that a recording is available and actually plays. Missing media alone does not identify a
synthetic interview; use the explicit simulation flag from interview metadata.

```
cookiy study interview playback url --study-id <uuid> [--interview-id <uuid>]
```

### study interview playback content

Get the content (transcript) of a specific interview. If `--interview-id` is not provided, returns
content for all interviews under the study.

```
cookiy study interview playback content --study-id <uuid> [--interview-id <uuid>]
```
