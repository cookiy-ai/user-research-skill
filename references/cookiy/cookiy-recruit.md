# Cookiy — Recruit Real Participants

Recruit real participants for qual studies (interviews) or quant surveys.

---

## Two-Step Confirm Flow

### Step 1 — Preview (omit `--confirmation-token`)

**Qual study:** `recruit start --study-id <uuid> --plain-text <s> [--incremental-participants <n>]`

**Quant survey:** `recruit start --survey-public-url <url> --plain-text <s> --incremental-participants <n>`

- `--plain-text` (required): real participant profile/requirements (e.g. country, language, age/sex, job). Infer from context; if unavailable, ask the user.
- `--incremental-participants`: required for quant surveys. For qual studies, omit to recruit up to the study's target sample size; can be called multiple times to recruit incrementally.

**IMPORTANT:** Show the preview from the response to the user. **Always wait for explicit confirmation before calling Step 2.**

**Preview response** — key fields to surface:

- `target_persona` — who will be recruited
- `cost_cents`, `shortfall_cents` — payment quote: total cost, and any balance shortfall
- `incremental_participants`, `total_participants_after` — participants added now, and the cumulative total after launch
- `pool_size_label` — coarse estimate of eligible participants, `Very limited` to `Very large`; a low value means the targeting is too narrow to fill the requested participants — suggest broadening `--plain-text`
- `remaining_capacity` — how many more participants the study can still recruit
- `confirmation_token` — pass to Step 2
- `status_message` — human-readable summary

### Step 2 — Confirm (once user confirmed)

**Qual:** `recruit start --study-id <uuid> --confirmation-token <token>`

**Quant:** `recruit start --confirmation-token <token>`

Recruitment takes hours to days. Use `study status` for qual studies or `quant status` for quant surveys to check progress.

If launch fails, no balance is deducted.

### Error: 409 — sample size already reached. Proceed to report instead.
