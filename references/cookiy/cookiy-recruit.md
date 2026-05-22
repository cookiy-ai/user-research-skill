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
- `pool_size_label` — coarse "volume" band of the eligible participant pool on the recruit panel that matches the criteria. **Always explain it — see below.**
- `pool_size_range` — the headcount range for that band (e.g. `10,000–99,999`); surface it alongside the label
- `confirmation_token` — pass to Step 2
- `status_message` — human-readable summary

**Explaining `pool_size_label`**

`pool_size_label` is a coarse volume band (`Very limited` → `Very large`), not an exact headcount; `pool_size_range` gives the matching headcount range. Surface both — the label on its own is not actionable — and pair them with the guidance for that band:

- `Very limited` — pool is very small; recruitment will likely stall or under-deliver. Loosen the criteria or cut the target count.
- `Low` — small pool; may fill slowly or only partially. Consider broadening the criteria.
- `Moderate` — workable pool; recruitment should fill, though a large batch may still take time.
- `Large` — plenty of participants; fills quickly.
- `Very large` — very deep pool; no supply concern.

### Step 2 — Confirm (once user confirmed)

**Qual:** `recruit start --study-id <uuid> --confirmation-token <token>`

**Quant:** `recruit start --confirmation-token <token>`

Recruitment takes hours to days. Use `study status` for qual studies or `quant status` for quant surveys to check progress.

If launch fails, no balance is deducted.

### Error: 409 — sample size already reached. Proceed to report instead.
