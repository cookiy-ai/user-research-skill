# Cookiy — Study Recruitment Operations

Commands for launching participant recruitment for interviews.

---

## CLI Commands

### study recruit start

Launch recruitment to find participants for a study's interviews. This is a two-step process:
preview first, then confirm to launch.

**Behavior:** Recruitment is bounded by the study's sample size. The system automatically caps
`--target-participants` to the remaining capacity (`sample_size - completed_participants`).
If the study has already reached its sample size, the command returns a 409 error.
You can call this command multiple times to recruit incrementally — if you pass a number smaller
than the current channel target, the system treats it as "recruit N more" (e.g. channel at 5,
pass 3 → total becomes 8). Values equal to or above the current target are used as-is.

```
scripts/cookiy.sh study recruit start --study-id <uuid> [--confirmation-token <s>] [--plain-text <s>] [--target-participants <n>]
```

| Flag | Required | Purpose |
|------|----------|---------|
| `--study-id` | yes | Target study |
| `--confirmation-token` | no | Token from the preview response — include this on the second call to actually launch |
| `--plain-text` | no | Participant profile / requirements to recruit. Only provide this if the user explicitly specifies who they want to recruit. If omitted, Cookiy generates it from the screening questions and research plan. |
| `--target-participants` | no | Number of participants to recruit. If the channel already has an active recruitment with a higher target, this value is treated as **incremental** ("recruit N more"). If omitted, the discussion guide's sample size is used. Always capped to remaining capacity. |

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
- `recruit_mode` — `qualitative_panel` or `quant_survey`
- `source_language` / `derived_languages` — detected languages (indicates discussion guide translation)
- `sample_size` / `interview_duration_minutes` — study parameters
- `target_group` — who will be recruited
- `payment_quote` — pricing details including `price_per_participant_cents`, `required_participants`, `purchased_participants`, `deficit_participants`, `amount_due_cents`, and `recruit_mode`
- `survey_public_url` — (quant only) the questionnaire URL

Null fields are omitted from the output.

**Show the preview to the user** and ask them to confirm whether to proceed. This step involves
payment, so always wait for explicit confirmation.

### Step 2 — Confirm and Launch

Once the user confirms, call `study recruit start` again with the `--confirmation-token`:

```
scripts/cookiy.sh study recruit start --study-id <uuid> --confirmation-token <token>
```

This launches the actual recruitment. The process takes time (hours to days depending on audience
criteria). Use `study status` from the main cookiy commands to check progress.

### Error: Study Sample Size Reached (409)

If the study has already completed enough participants to fill the sample size, the command returns:

```json
{
  "ok": false,
  "status_code": 409,
  "code": "STUDY_SAMPLE_SIZE_REACHED",
  "sample_size": 12,
  "completed_participants": 12
}
```

No further recruitment is needed. Proceed to report generation instead.
