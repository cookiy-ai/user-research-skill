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
VS Code, Windsurf, Cline, OpenClaw, Manus, etc.) and install ONLY for
that client. Do not install for all clients at once.

Pick the matching command:

| You are running in | Install command |
|---|---|
| Codex | `npx cookiy-mcp --client codex -y` |
| Claude Code | `npx cookiy-mcp --client claudeCode -y` |
| Cursor | `npx cookiy-mcp --client cursor -y` |
| Cline | `npx cookiy-mcp --client cline -y` |
| GitHub Copilot / VS Code | `npx cookiy-mcp --client vscode -y` |
| Windsurf | `npx cookiy-mcp --client windsurf -y` |
| OpenClaw | `npx cookiy-mcp --client openclaw -y` |
| Manus / headless sandbox | `npx cookiy-mcp --client manus -y` |
| Other / unknown | `npx cookiy-mcp -y` (auto-detects production) |

If your agent is not in the table above but supports MCP over HTTP,
you can manually configure the MCP server URL: `https://s-api.cookiy.ai/mcp`
with OAuth authentication. See the MCP server's OAuth discovery at
`https://s-api.cookiy.ai/.well-known/oauth-authorization-server`.

For headless sandbox environments such as Manus, use
`npx cookiy-mcp --client manus -y`. The installer writes a resumable
OAuth helper bundle under `~/.mcp/<server>/`.

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
| Get workflow help on a topic | Direct: `cookiy_help` (`overview`, `study`, `ai_interview`, `guide`, `recruitment`, `report`, `billing`; common aliases accepted) | — |

When the user's intent spans multiple workflows (e.g., "create a study
and run interviews"), execute them sequentially in the order listed above.

### Universal Rules

See tool-contract.md for the complete specification.

**Response handling:**
- ALWAYS read `structuredContent` first. Fall back to `content[0].text` only when `structuredContent` is absent.
- ALWAYS check `next_recommended_tools` in each response. Prefer the server's recommendation over your own judgment.
- ALWAYS obey `status_message` — it contains server-side behavioral directives, not just informational text.
- When `presentation_hint` is present, format output accordingly.
- For recruitment truth, prefer evidence in this order: `cookiy_interview_list` > `cookiy_recruit_status` (use `sync: true` when you need a fresh check) > the latest `cookiy_recruit_create` response > `cookiy_study_get.state`.
- NEVER describe recruitment as started/stopped from preview-only output.

**Identifiers:**
- NEVER truncate, reformat, or summarize `study_id`, `job_id`, `interview_id`, `base_revision`, or `confirmation_token`.

**Payment:**
- On HTTP 402: prefer `structuredContent.data.payment_summary` and `checkout_url`; if those fields are absent, fall back to `error.details`.
- `cookiy_balance_get` may show `experience_bonus`; eligible MCP actions may consume that bonus before purchased credit.
- Experience bonus may apply to study creation, simulated interviews, and report access via `cookiy_report_share_link_get`.
- Experience bonus does NOT cover: recruitment (recruitment requires paid credit or cash credit).

**URLs:**
- NEVER construct URLs manually. ONLY use URLs from tool responses.
- NEVER guess undocumented REST paths.

**Agent boundary:**
- After recruitment payment, check `cookiy_recruit_status` first and `cookiy_interview_list` second before deciding whether to retry `cookiy_recruit_create`.
- Do not promise background monitoring unless a real automation layer exists outside the current MCP call.

**Constraints:**
- `interview_duration` max 15 minutes. `persona.text` max 4000 chars. `interviewee_personas` max 20. `attachments` max 10.

### Canonical reference

The server's developer portal spec endpoint provides the authoritative
tool reference. If a tool behaves differently from this skill's
description, the server's runtime behavior takes precedence.
