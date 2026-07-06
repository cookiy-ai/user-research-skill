<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Recruit Real Participants

Recruit real participants for qual studies (interviews) or quant surveys.

---

## Two-Step Confirm Flow

### Step 1 — Preview (omit `--confirmation-token`)

**Qual study:** `recruit start --study-id <uuid> --plain-text <s> [--incremental-participants <n>]`

**Quant survey:** `recruit start --survey-public-url <url> --plain-text <s> --incremental-participants <n>`

- `--plain-text` (required): real participant profile/requirements (e.g. country, language, age/sex, job). Infer from context; if unavailable, ask the user.
- `--incremental-participants`: required for quant surveys. For qual studies, omit to recruit up to the study's target sample size; can be called multiple times to recruit incrementally.

**Criteria quality check:** Before calling Step 1, assess whether the `--plain-text` criteria are too strict, niche, or have too many restrictions. Real participants are recruited from a real market — overly narrow criteria shrink the available pool significantly. Use your judgment; if criteria seem excessive, proactively suggest relaxing them before proceeding.

**IMPORTANT:** Show the preview response (including payment quote and pool size) to the user.
- If the pool size is small, warn the user that recruitment may take a very long time or fail to complete, and suggest relaxing the criteria.
- **Always wait for explicit confirmation before calling Step 2.**

### Step 2 — Confirm (once user confirmed)

**Qual:** `recruit start --study-id <uuid> --confirmation-token <token>`

**Quant:** `recruit start --confirmation-token <token>`

Recruitment takes hours to days. Use `study status` for qual studies or `quant status` for quant surveys to check progress.

If launch fails, no balance is deducted.

### Error: 409 — sample size already reached. Proceed to report instead.
