---
name: cookiy
description: >
  AI-powered user research through natural language. Installs the Cookiy
  MCP server and orchestrates tool workflows for study creation,
  AI interviews, discussion guide editing, participant recruitment,
  and report generation.
---

# Cookiy

Cookiy gives your AI agent user-research capabilities. It designs
interview guides, conducts AI-moderated interviews with real or
simulated participants, and generates insight reports — all through
natural language.

---

## Part 1 — Setup

### When to run setup

- User mentions Cookiy, user research, voice interviews, or participant recruitment
- Any `cookiy_*` tool call fails with a connection or "tool not found" error
- User explicitly asks to set up or connect Cookiy
- User asks what Cookiy can do

### Check if already connected

Try calling `cookiy_introduce`. If it succeeds, skip to Part 2.

### Install the MCP server

Identify which AI client you are running in (Codex, Claude Code, Cursor,
OpenClaw, etc.) and install ONLY for that client. Do not install for all
clients at once.

Pick the matching command:

| You are running in | Install command |
|---|---|
| Codex | `brew install cookiy-ai/tap/cookiy && cookiy --client codex -y` |
| Claude Code | `brew install cookiy-ai/tap/cookiy && cookiy --client claude-code -y` |
| Cursor | `brew install cookiy-ai/tap/cookiy && cookiy --client cursor -y` |
| OpenClaw | `npx cookiy-mcp --client openclaw -y` |
| Other / unknown | `npx cookiy-mcp -y` (auto-detects) |

If `brew` is not available, replace `brew install cookiy-ai/tap/cookiy && cookiy`
with `npx cookiy-mcp` in the commands above.

The installer will prompt for OAuth authentication. This is expected.

### Verify the connection

After installation, call `cookiy_introduce` to confirm the MCP server
is connected and authenticated.

If authentication fails:
- Re-run the install command. Do NOT remove and reinstall the server.
- The OAuth token may have expired. The installer handles re-authentication.

### Orient the user

Present Cookiy's five capability modules:

1. **Study Creation** — Describe a research goal and get an AI-generated discussion guide.
2. **AI Interview** — Simulate interviews with AI personas for quick insights.
3. **Discussion Guide** — Review and edit the interview script before going live.
4. **Recruitment** — Recruit real participants for AI-moderated interviews.
5. **Report & Insights** — Generate analysis reports and shareable links.

Present these in plain language. Do not expose raw tool names to the user.

---

## Part 2 — Workflow Orchestration

Cookiy is a workflow-aware MCP server, not a raw REST passthrough.
Every operation must go through the official `cookiy_*` MCP tools.
Follow the tool contract and workflow state machines in the reference files.

### Intent Router

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

When the user's intent spans multiple workflows (e.g., "create a study
and run interviews"), execute them sequentially in the order listed above.

### Universal Rules

See tool-contract.md for the complete specification.

**Response handling:**
- ALWAYS read `structuredContent` first. Fall back to `content[0].text` only when `structuredContent` is absent.
- ALWAYS check `next_recommended_tools` in each response. Prefer the server's recommendation over your own judgment.
- ALWAYS obey `status_message` — it contains server-side behavioral directives, not just informational text.
- When `presentation_hint` is present, format output accordingly.

**Identifiers:**
- NEVER truncate, reformat, or summarize `study_id`, `job_id`, `interview_id`, `base_revision`, or `confirmation_token`.

**Payment:**
- On HTTP 402: display `error.details.payment_summary`, then offer `checkout_url`.
- Trial balance covers: study creation, simulated interviews, report generation.
- Trial balance does NOT cover: recruitment (always charged separately).

**URLs:**
- NEVER construct URLs manually. ONLY use URLs from tool responses.
- NEVER guess undocumented REST paths.

**Constraints:**
- `interview_duration` max 15 minutes. `persona.text` max 4000 chars. `interviewee_personas` max 20. `attachments` max 10.

### Canonical reference

The server's developer portal spec endpoint provides the authoritative
tool reference. If a tool behaves differently from this skill's
description, the server's runtime behavior takes precedence.
