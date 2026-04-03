# Cookiy — Study Recruitment Operations

Commands for launching participant recruitment for interviews.

---

## CLI Commands

### recruit start

Launch recruitment to find participants for a study's interviews. This is a two-step process:
preview first, then confirm to launch.

**Important:** Each study has only one recruit. Calling this command multiple times replaces the
previous recruit (e.g. first call with `--target-participants 10`, second call with
`--target-participants 12` — the study ends up with 12).

```
scripts/cookiy.sh recruit start --study-id <uuid> [--confirmation-token <s>] [--plain-text <s>] [--target-participants <n>]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--study-id` | yes | Target study |
| `--confirmation-token` | no | Token from the preview response — include this on the second call to actually launch |
| `--plain-text` | no | Participant profile / requirements to recruit. Only provide this if the user explicitly specifies who they want to recruit. If omitted, Cookiy generates it from the screening questions and research plan. |
| `--target-participants` | no | Number of participants to recruit. If omitted, the discussion guide's sample size is used. Don't provide unless the user specifically requests a number. |

---

## Workflow

Recruitment is a **two-step confirm flow**:

### Step 1 — Preview

Call `recruit start` **without** `--confirmation-token`:

```
scripts/cookiy.sh recruit start --study-id <uuid> [--plain-text <s>] [--target-participants <n>]
```

The response contains:
- `confirmation_token` — needed for step 2
- `study_summary` — overview of the study
- `targeting_preview` — who will be recruited and how

**Show the preview to the user** and ask them to confirm whether to proceed. This step involves
payment, so always wait for explicit confirmation.

### Step 2 — Confirm and Launch

Once the user confirms, call `recruit start` again with the `--confirmation-token`:

```
scripts/cookiy.sh recruit start --study-id <uuid> --confirmation-token <token>
```

This launches the actual recruitment. The process takes time (hours to days depending on audience
criteria). Use `study status` from the main cookiy commands to check progress.
