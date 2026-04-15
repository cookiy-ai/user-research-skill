# Cookiy — Qualitative User Research (Interview Study)

## Workflow Overview

```
Research Goal
  │
  ▼
study create  ──→  Discussion Guide (generated async)
  │
  ▼
Review Guide  ──→  (optional) show/edit the guide
  │
  ├──→  Recruit real participants  (costs money, takes time)
  │         or
  └──→  Synthetic user interviews with AI personas  (cheaper, faster)
          │
          ▼
     Interviews Complete
          │
          ▼
     Pull report / transcripts / playback URLs
```

---

## CLI Commands

### study list

Fetch existing studies.

```
scripts/cookiy.sh study list [--limit <n>] [--cursor <s>]
```

### study create

Create a new study. It automatically creates the discussion/interview guide (generated asynchronously).

```
scripts/cookiy.sh study create --query <s> [--thinking <s>] [--attachments <s>]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--query` | yes | Research goal for the AI moderator. Can be a brief goal or full plan/interview guide. Include any non-public background knowledge the AI moderator needs (product context, internal knowledge, recent events, etc.). |
| `--thinking` | no | `medium` or `high`. Use when the query is rough or vague so the backend reasons more carefully. Omit for well-defined queries. |
| `--attachments` | no | JSON array of `{s3_key, description}`, max 10 items. `s3_key` comes from the `study upload` command response. `description` is required. |

### study upload

Upload an image and get an s3 key back. The key can be used in `study create --attachments` or in
guide update payloads.

```
scripts/cookiy.sh study upload --content-type <s> (--image-data <s> | --image-url <s>)
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--content-type` | yes | MIME type (e.g. `image/jpeg`) |
| `--image-data` | one of these | Base64 data **without** the `data:` prefix |

### study status

Check the current stage of a study (guide generation, recruitment, interviews, etc.). Call this
whenever you need to know what's happening before taking the next step.

```
scripts/cookiy.sh study status --study-id <uuid>
```

---

## Waiting on Async Operations

Guide, report generation expose a `wait` subcommand (see the relevant sub-reference) to block until complete. Use it only when the user explicitly asks to wait. For all other progress checks, use `study status`.

---

## Sub-References

Only read these when you need to perform the specific operation:

| File | Covers |
|------|--------|
| [`cookiy-study-guide.md`](cookiy-study-guide.md) | Viewing and editing discussion guides |
| [`cookiy-recruit.md`](cookiy-recruit.md) | Launching and managing real participant recruitment |
| [`cookiy-study-synthetic-user.md`](cookiy-study-synthetic-user.md) | Running synthetic user interviews with AI personas |
| [`cookiy-study-interview.md`](cookiy-study-interview.md) | Interview retrieval for both real and synthetic interviews (playback link and transcript) |
| [`cookiy-study-report.md`](cookiy-study-report.md) | Report retrieval (link and content) |

---

## Decision Points

When guiding a user through the workflow, there are two key moments to ask:

1. **After guide generation** — offer to show the discussion guide. If they want changes, use the
   guide editing commands.
2. **Before interviews** — confirm the participant profile/requirements (at minimum: target countries and languages). Then ask: real participants (costs money, takes time, human responses) or synthetic user interviews (faster, cheaper, good for piloting)?
