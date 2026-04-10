# Cookiy — Synthetic User Interview Operations

Commands for launching synthetic user (not real participant) interviews for a study.

---

## CLI Commands

### study run-synthetic-user start

Run synthetic user interviews with AI personas.

```
scripts/cookiy.sh study run-synthetic-user start --study-id <uuid> [--persona-count <n>] [--plain-text <s>]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--persona-count` | no | Number of new synthetic interviews to run. |
| `--plain-text` | no | Synthetic user profile/requirements (e.g. country, languages, age/sex, job). Provide if any such context is available. |
