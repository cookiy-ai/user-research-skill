---
name: cookiy-workflows
description: >
  Workflow orchestration for Cookiy MCP tools. Routes user intents to the
  correct tool chain for AI-powered user research: study creation,
  AI interviews, discussion guide editing, participant recruitment,
  and report generation. Enforces tool sequencing, payment safety,
  and state machine rules that are not obvious from tool descriptions alone.
---

# Cookiy Workflows

Cookiy is a workflow-aware MCP server, not a raw REST passthrough.
Every Cookiy operation must go through the official `cookiy_*` MCP tools.
Follow the tool contract and workflow state machines defined in the
reference files below.

## Intent Router

Route the user's request to the correct workflow:

| User wants to... | Workflow | Reference file |
|---|---|---|
| Create a new study or research project | Study Creation | study-creation.md |
| Run simulated or AI-to-AI interviews | AI Interview | ai-interview.md |
| View or edit the discussion guide | Guide Editing | guide-editing.md |
| Recruit real participants | Recruitment | recruitment.md |
| Generate, check, or share a report | Report & Insights | report-insights.md |
| Check account balance | Direct: `cookiy_balance_get` | — |
| List existing studies | Direct: `cookiy_study_list` | — |
| Learn what Cookiy can do | Direct: `cookiy_introduce` | — |
| Get workflow help on a topic | Direct: `cookiy_help` | — |

When the user's intent spans multiple workflows (e.g., "create a study and
run interviews"), execute them sequentially in the order listed above.

## Universal Rules

These rules apply to every Cookiy tool call. See tool-contract.md for the
complete specification.

### Response handling

- ALWAYS read `structuredContent` first. Fall back to `content[0].text`
  only when `structuredContent` is absent.
- ALWAYS check `next_recommended_tools` in each response. Prefer the
  server's recommendation over your own judgment for the next step.
- ALWAYS obey `status_message` — it contains server-side behavioral
  directives, not just informational text.
- When `presentation_hint` is present, format output accordingly
  (markdown table, markdown link, heading groups, etc.).

### Identifiers

- NEVER truncate, reformat, or summarize `study_id`, `job_id`,
  `interview_id`, `base_revision`, or `confirmation_token`.
- Copy identifiers exactly as returned by the server.

### Payment

- On HTTP 402: display `error.details.payment_summary` to the user,
  then offer `error.details.checkout_url` as the payment link.
- NEVER recalculate prices from quote fields.
- Trial balance covers: study creation, simulated interviews,
  report generation.
- Trial balance does NOT cover: recruitment (always charged separately).

### URLs

- NEVER construct URLs manually (share links, playback links, checkout).
- ONLY use URLs returned in tool responses.
- NEVER guess undocumented REST paths.

### Constraints

- `interview_duration` must be 15 minutes or less (MCP enforced).
- `persona.text` max 4000 characters.
- `interviewee_personas` max 20 items.
- `attachments` max 10 items per study.

## Canonical reference

The server's developer portal spec endpoint provides the authoritative
tool reference. If a tool behaves differently from this skill's
description, the server's runtime behavior takes precedence.
