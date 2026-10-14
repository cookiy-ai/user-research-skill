<!-- Part of the Cookiy user-research skill · https://github.com/cookiy-ai/user-research-skill -->

# Cookiy — Recruit Real Participants

Recruit real participants for qual studies (interviews) or quant surveys.

---

## Two-Step Confirm Flow

### Step 1 — Preview (omit `--confirmation-token`)

**Qual study:** `cookiy recruit start --study-id <uuid> --plain-text <s> [--incremental-participants <n>]`

**Quant survey:** `cookiy recruit start --survey-public-url <url> --plain-text <s> --incremental-participants <n>`

- `--plain-text` (required): real participant profile/requirements (e.g. country, language, age/sex, job). Infer from context; if unavailable, ask the user.
- `--incremental-participants`: specify the number to recruit for quant surveys. For qual studies, omit to recruit up to the study's target sample size; can be called multiple times to recruit incrementally.

**Criteria quality check:** Before calling Step 1, assess whether the `--plain-text` criteria are too strict, niche, or have too many restrictions. Real participants are recruited from a real market — overly narrow criteria shrink the available pool significantly. Use your judgment; if criteria seem excessive, proactively suggest relaxing them before proceeding.

**IMPORTANT:** Show the preview response (including payment quote and pool size) to the user.
- If the pool size is small, warn the user that recruitment may take a very long time or fail to complete, and suggest relaxing the criteria.
- **Always wait for explicit confirmation before calling Step 2.**

### Step 2 — Confirm (once user confirmed)

**Qual:** `cookiy recruit start --study-id <uuid> --confirmation-token <token>`

**Quant:** `cookiy recruit start --survey-public-url <url> --confirmation-token <token>`

Reuse the study ID or survey URL from Step 1. The CLI requires one of them to select the recruitment route even when a confirmation token is supplied.

Recruitment takes hours to days. Use `cookiy study status --study-id <uuid>` for qual studies or `cookiy quant status --survey-id <n>` for quant surveys to check progress.

### Error: 409 — sample size already reached. Proceed to report instead.
