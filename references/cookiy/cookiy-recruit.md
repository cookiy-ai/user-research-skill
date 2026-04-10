# Cookiy — Recruit Real Participants

Recruit real participants for qual studies (interviews) or quant surveys.

---

## Two-Step Confirm Flow

### Step 1 — Preview (omit `--confirmation-token`)

**Qual study:** `recruit start --study-id <uuid> [--plain-text <s>] [--incremental-participants <n>]`

**Quant survey:** `recruit start --survey-public-url <url> [--plain-text <s>] [--incremental-participants <n>]`

- `--plain-text`: real participant profile/requirements (e.g. country, language, age/sex, job). Provide if any such context is available.
- `--incremental-participants`: defaults to target sample size. Can call multiple times to recruit incrementally.

Show the preview (including payment quote) to the user. Always wait for explicit confirmation.

### Step 2 — Confirm (once user confirmed)

**Qual:** `recruit start --study-id <uuid> --confirmation-token <token>`

**Quant:** `recruit start --confirmation-token <token>`

Recruitment takes hours to days. Use `study status` for qual studies or `quant report` for quant surveys to check progress.

### Error: 409 — sample size already reached. Proceed to report instead.
