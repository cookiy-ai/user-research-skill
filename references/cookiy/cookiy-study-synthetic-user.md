# Cookiy — Synthetic User Interview Operations

Commands for launching synthetic user (not real participant) interviews for a study.

---

## CLI Commands

### study run-synthetic-user start

Run synthetic user interviews with AI personas.

```
scripts/cookiy.sh study run-synthetic-user start --study-id <uuid> [--persona-count <n>] [--plain-text <s>] [--wait]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--persona-count` | no | Number of new synthetic interviews to run. |
| `--plain-text` | no | Participant profile / requirements. Only provide this if the user explicitly specifies who they want. If omitted, Cookiy generates it from the screening questions and research plan. |
| `--wait` | no | Wait until all synthetic interviews complete. Include this by default. |
