---
name: cookiy
description: >
  AI-powered user research through natural language. Use the Cookiy CLI
  and hosted API for study creation, AI interviews, discussion guide editing,
  participant recruitment, report generation, and optional quantitative
  questionnaires.
---

# Cookiy

Cookiy gives your AI agent user-research capabilities: interview guides,
AI-moderated interviews with real or simulated participants, and insight
reports — driven through **terminal commands** against the Cookiy hosted
service.

---

## Progressive disclosure

0. **Stay in this file first.** Do not load all `references/*.md` or the
   full `cli/commands.md` unless the user asks for a deep read.
1. **Credentials + health:** follow [`cli/commands.md`](cli/commands.md)
   (environment variables, default credential paths). Then run
   `cookiy doctor` via
   [`scripts/cookiy.sh`](scripts/cookiy.sh) or a globally linked `cookiy`
   binary from the `cookiy-mcp` package. Do not paste raw tokens into chat.
2. **Route by intent (one reference):** open exactly **one** workflow file
   from the Intent Router below. For natural-language progress questions,
   start with `cookiy study progress` or `cookiy study show`.
3. **Cross-cutting rules:** billing, HTTP 402, identifiers, pacing, and
   server hints → [`references/tool-contract.md`](references/tool-contract.md).
4. **Quantitative studies:** `cookiy help quantitative` and the quantitative
   section in this file, then `tool-contract.md`.
5. **Shell execution:** agents should invoke
   `skills/cookiy/scripts/cookiy.sh` (or `./cookiy` at the repo root)
   with `run_terminal_cmd` when executing Cookiy.
6. **Pure methodology (no Cookiy API):** use
   [`../pm-research/SKILL.md`](../pm-research/SKILL.md) only when the user
   wants general research methods, not platform operations.
7. **Packaged layouts:** the same skill tree ships under
   `packages/cookiy-mcp/skill-assets/`; keep paths in sync when editing.

---

## Part 1 — Setup and health

### Before business operations

Always confirm Cookiy is reachable with valid credentials:

1. Ensure credentials exist (see `cli/commands.md`).
2. Run `cookiy doctor` (introduce / connectivity). If it fails, run
   **`cookiy login`** (browser OAuth to the default credentials path) or
   repair via `npx cookiy-mcp --client …` when the user also needs IDE/skill
   install.
3. If the user’s goal is exclusively setup or repair, stop after a short,
   plain-language success message — do not jump into research intake.

When `cookiy doctor` is only used as a smoke test, summarize the outcome in
one sentence for the user. Do not dump raw JSON unless debugging.

### Capability overview (when the user asks what Cookiy does)

Present Cookiy’s six modules in plain language (qualitative and
quantitative are **parallel** — same agent, complementary methods):

1. **Study creation** — describe a goal; get an AI-generated discussion guide.
2. **AI interview** — simulate interviews with AI personas.
3. **Discussion guide** — review and edit the script before going live.
4. **Recruitment** — recruit participants for AI-moderated interviews.
5. **Report and insights** — generate reports and shareable links.
6. **Quantitative survey** — structured questionnaires and analysis when
   enabled for the workspace (see `cookiy help quantitative`).

Avoid listing low-level server identifiers in user-facing prose.

---

## Part 2 — Workflow orchestration

### Intent Router

| User wants to… | Workflow | Reference file |
| --- | --- | --- |
| Create a study or research project | Study creation | [`references/study-creation.md`](references/study-creation.md) |
| Simulated or AI-to-AI interviews | AI interview | [`references/ai-interview.md`](references/ai-interview.md) |
| View or edit the discussion guide | Guide editing | [`references/guide-editing.md`](references/guide-editing.md) |
| Recruit real participants | Recruitment | [`references/recruitment.md`](references/recruitment.md) |
| Report status or share link | Report and insights | [`references/report-insights.md`](references/report-insights.md) |
| Quantitative questionnaires | Quantitative survey | `cookiy help quantitative` + [`references/tool-contract.md`](references/tool-contract.md) |
| Natural-language study progress | Prefer `cookiy study progress` / `cookiy study show` | [`references/tool-contract.md`](references/tool-contract.md) |
| Add cash credit (USD cents) | `cookiy billing checkout` | [`references/tool-contract.md`](references/tool-contract.md) |
| Check balance | `cookiy billing balance` | [`references/tool-contract.md`](references/tool-contract.md) |
| List studies | `cookiy study list` | [`cli/commands.md`](cli/commands.md) |
| Platform overview / connectivity blurb | `cookiy doctor` | — |
| Workflow help by topic | `cookiy help <topic>` | [`cli/commands.md`](cli/commands.md) |

### Multipart requests

When the user’s goal spans workflows (for example “create a study and run
interviews”), execute them in a sensible dependency order: study creation →
guide readiness → interviews or recruitment → reporting.

### Universal rules

See [`references/tool-contract.md`](references/tool-contract.md) for the full
specification. In short:

- **Responses:** prefer `structuredContent`; fall back to `content[0].text`
  only if needed.
- **Hints:** honor `next_recommended_tools`, `status_message`, and
  `presentation_hint`.
- **Progress questions:** prefer `cookiy study progress` before drilling into
  atomic operations.
- **Quantitative default chain** unless the server directs otherwise:
  `cookiy quant list` or `cookiy quant create` → `cookiy quant detail` →
  `cookiy quant patch` (if editing) → `cookiy quant report` after responses
  exist; use `cookiy quant results` only when raw exports are explicitly
  required.
- **Recruitment evidence order:** `cookiy interview list` →
  `cookiy recruit status` → latest `cookiy recruit start` response →
  `cookiy study get` state.
- **Identifiers:** never truncate or rewrite `study_id`, `job_id`,
  `interview_id`, `base_revision`, `confirmation_token`, etc.
- **Payments (HTTP 402):** follow `structuredContent.data.payment_summary`
  and `checkout_url` when present; otherwise parse `error.details`.
- **Checkout outside a 402 flow:** `cookiy billing checkout`, then
  `cookiy billing balance`.
- **URLs:** only use URLs returned by Cookiy; never guess undocumented REST
  paths.
- **Constraints:** interview duration cap (15 minutes), persona text limits,
  attachment limits — see workflow docs.

### Canonical reference

If the live hosted service disagrees with this skill, **the service wins**.
Use the developer portal / public specification referenced from
`tool-contract.md` when you need field-level truth.

---

## CLI and docs index

| Resource | Path |
| --- | --- |
| Command tree, flags, environment | [`cli/commands.md`](cli/commands.md) |
| Wrapper (repo) | [`scripts/cookiy.sh`](scripts/cookiy.sh) |
| Cross-cutting API semantics | [`references/tool-contract.md`](references/tool-contract.md) |
