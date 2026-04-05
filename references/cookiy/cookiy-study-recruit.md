# Cookiy — Study Recruitment Operations

Commands for launching participant recruitment for interviews.

---

## CLI Commands

### study recruit start

Launch recruitment to find participants for a study's interviews. This is a two-step process:
preview first, then confirm to launch.

**Behavior:** Recruitment is bounded by the study's sample size. The system automatically caps
`--incremental-participants` to the remaining capacity (`sample_size - completed_participants`).
You can call this command multiple times to recruit incrementally.

```
scripts/cookiy.sh study recruit start --study-id <uuid> [--confirmation-token <s>] [--plain-text <s>] [--incremental-participants <n>]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--confirmation-token` | no | Token from the preview response — include this on the second call to actually launch |
| `--plain-text` | no | Participant profile / requirements to recruit. Only provide this if the user explicitly specifies who they want to recruit. If omitted, Cookiy generates it from the screening questions and research plan. |
| `--incremental-participants` | no | Number of incremental participants to recruit. If omitted, the discussion guide's sample size is used. |

---

## Workflow

Recruitment is a **two-step confirm flow**:

### Step 1 — Preview

Call `study recruit start` **without** `--confirmation-token`:

```
scripts/cookiy.sh study recruit start --study-id <uuid> [--plain-text <s>] [--target-participants <n>]
```

The response contains:
- `confirmation_token` — needed for step 2

**Show the preview (including the payment quote) to the user** and ask them to confirm whether to proceed. This step involves
payment, so always wait for explicit confirmation.

### Step 2 — Confirm and Launch

Once the user confirms, call `study recruit start` again with the `--confirmation-token`:

```
scripts/cookiy.sh study recruit start --study-id <uuid> --confirmation-token <token>
```

This launches the actual recruitment. The process takes time (hours to days depending on audience
criteria). Use `study status` from the main cookiy commands to check progress.

### Error: Study Sample Size Reached (409)

If the study has already completed enough participants to fill the sample size, the command returns status_code 409.
No further recruitment is needed. Proceed to report generation instead.
