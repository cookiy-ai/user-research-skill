# Cookiy AI — End-to-End User Research via CLI

Cookiy AI automates the full qualitative research lifecycle: study creation, discussion guide
generation, participant recruitment (or simulated interviews with AI personas), AI-moderated
interviews, and report synthesis. All operations go through the [`scripts/cookiy.sh`](scripts/cookiy.sh) CLI.

---

## Workflow Overview

```
Research Goal
  │
  ▼
study create  ──→  Discussion Guide (generated async, use --wait)
  │
  ▼
Review Guide  ──→  (optional) show/edit the guide
  │
  ├──→  Recruit real participants  (costs money, takes time)
  │         or
  └──→  Simulated interviews with AI personas  (cheaper, faster)
          │
          ▼
     Interviews Complete
          │
          ▼
     Pull report / transcripts / playback URLs
```

---

## Authentication

The CLI needs a saved access token. If any command returns an auth error — no token, expired token,
or a response containing a login URL — handle it like this:

1. Tell the user they need to sign in. The login URL is shown in the CLI error output. Include this
   URL in your message so the user can open it directly, and ask them to copy the access token back
   to you once logged in.
3. Use the `save-token` CLI command to save it.
4. Automatically re-run the command that originally failed.

---

## CLI Commands

All commands are run via [`scripts/cookiy.sh`](scripts/cookiy.sh).

### Study

**study list** — Fetch existing studies. Returns study IDs, project names, etc.

```
scripts/cookiy.sh study list [--limit <n>] [--cursor <s>]
```

**study create** — Create a study from a natural-language research goal. The discussion guide is
generated asynchronously.

```
scripts/cookiy.sh study create --query <s> --language <s> [--thinking <s>] [--attachments <s>] [--wait]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--query` | yes | Natural language — can be a one-sentence goal or a complete research plan / interview guide |
| `--language` | yes | Discussion guide language (e.g. `en`, `zh`) |
| `--thinking` | no | Add when the query is rough or vague so the backend reasons more carefully. Omit for well-defined queries. |
| `--attachments` | no | Path to supplementary files |
| `--wait` | no | Wait until the discussion guide finishes generating before returning. Include this by default. |

The response includes a **study ID** — save it; every subsequent command needs it.

**study status** — Check the current stage of a study (guide generation, recruitment, interviews,
etc.). Call this whenever you need to know what's happening before taking the next step.

```
scripts/cookiy.sh study status --study-id <uuid>
```

#### Other Study Sub-References

Only read these when you need to perform the specific operation:

| File | Covers |
|------|--------|
| [`cookiy-study-guide.md`](cookiy-study-guide.md) | Viewing and editing discussion guides |
| [`cookiy-study-recruit.md`](cookiy-study-recruit.md) | Launching and managing participant recruitment |
| [`cookiy-study-simulated.md`](cookiy-study-simulated.md) | Running simulated interviews with AI personas |

#### Report

**report link** — Get the public URL for the study report.

```
scripts/cookiy.sh report link --study-id <uuid>
```

**report content** — Get the markdown content of the study report directly.

```
scripts/cookiy.sh report content --study-id <uuid>
```

### Billing

Payment and billing related guidance and operations. Refer to [`cookiy-billing.md`](cookiy-billing.md).

### Auth

**save-token** — Store an access token obtained from browser sign-in.

```
scripts/cookiy.sh save-token <access_token>
```

---

## Decision Points

When guiding a user through the workflow, there are two key moments to ask:

1. **After guide generation** — offer to show the discussion guide. If they want changes, use the
   guide editing commands.
2. **Before interviews** — ask whether they want real participants or simulated interviews:
   *"Would you like to recruit real participants (takes longer, costs more, gives real human
   responses) or run simulated interviews with AI personas (faster and cheaper, good for piloting)?"*

