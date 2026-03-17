# Cookiy Skill

Turn Claude Code, Codex, Cursor, OpenClaw, and other MCP clients into AI user-research operators that can create studies, run interviews, recruit participants, and deliver report links from plain-English prompts.

## 30-Second Demo

```bash
# Install Cookiy for your AI client
npx cookiy-mcp --client codex -y

# Then ask your agent:
"Create a 6-participant checkout-abandonment study in English."
"Run 3 simulated interviews with price-sensitive mobile shoppers."
"Share the report link as soon as a preview is ready."
```

What happens:

- Cookiy creates the study and discussion guide inside your agent workflow.
- It runs or monitors interviews and recruitment through the MCP tool chain.
- It returns transcripts, status updates, and share links without leaving chat.

## 3 Real Examples

| Use case | Ask your agent | What Cookiy does |
|---|---|---|
| Ecommerce checkout drop-off | "Create a 6-participant study to understand why mobile shoppers abandon checkout after shipping costs appear." | Creates the study, generates the guide, and highlights sample size, interview mode, and duration for review. |
| SaaS onboarding friction | "Run 5 simulated interviews with first-time admins setting up SSO for the first time." | Queues AI interviews, polls status, and returns transcripts for early signal before spending on real participants. |
| Concept validation with real users | "Recruit bilingual parents in the US for 8 short interviews about a children's learning app, then share the report link when ready." | Previews targeting and pricing, launches recruitment after confirmation, tracks progress, and returns the report share link when available. |

## Quick Install

### Claude Code

Install as a plugin directly in Claude Code:

```bash
claude plugin add cookiy-ai/cookiy-skill
```

Or install the MCP server standalone:

```bash
npx cookiy-mcp --client claudeCode -y
```

### Codex

```bash
npx skills add cookiy-ai/cookiy-skill
```

Or install the MCP server directly:

```bash
npx cookiy-mcp --client codex -y
```

### OpenClaw

```bash
clawhub install cookiy
```

Or install the MCP server directly:

```bash
npx cookiy-mcp --client openclaw -y
```

### Cursor

Install from the [Cursor Marketplace](https://cursor.com/marketplace), or manually:

```bash
npx cookiy-mcp --client cursor -y
```

### Any platform with Node.js

```bash
npx cookiy-mcp -y
```

The installer auto-detects installed AI clients and configures them.

## Verification Matrix

Validation note: rows below reflect direct `cookiy-mcp` CLI dry-runs against the live installer contract.

| Client | Direct install command | Local validation status | Last verified |
|---|---|---|---|
| Claude Code | `npx cookiy-mcp --client claudeCode -y` | CLI dry-run verified, client detected locally | 2026-03-17 |
| Codex | `npx cookiy-mcp --client codex -y` | CLI dry-run verified, client detected locally | 2026-03-17 |
| Cursor | `npx cookiy-mcp --client cursor -y` | CLI dry-run verified, client detected locally | 2026-03-17 |
| GitHub Copilot / VS Code | `npx cookiy-mcp --client vscode -y` | CLI dry-run verified, client detected locally | 2026-03-17 |
| OpenClaw | `npx cookiy-mcp --client openclaw -y` | CLI dry-run verified, client detected locally | 2026-03-17 |
| Windsurf | `npx cookiy-mcp --client windsurf -y` | CLI dry-run verified via forced client selection | 2026-03-17 |
| Cline | `npx cookiy-mcp --client cline -y` | CLI dry-run verified via forced client selection | 2026-03-17 |

## What's in this repo

```
cookiy-skill/
├── .claude-plugin/plugin.json     # Claude Code plugin manifest
├── .cursor-plugin/plugin.json     # Cursor plugin manifest
├── .mcp.json                      # MCP server auto-registration
├── assets/
│   └── logo.svg                   # Cookiy logo
├── rules/
│   └── cookiy-basics.mdc          # Cursor rules for MCP interaction
├── skills/
│   └── cookiy/                    # Single unified skill
│       ├── SKILL.md               # Setup + intent router + universal rules
│       └── references/
│           ├── tool-contract.md   # Cross-workflow behavior contract
│           ├── study-creation.md  # Create studies from research goals
│           ├── ai-interview.md    # Simulate interviews with AI personas
│           ├── guide-editing.md   # Edit discussion guides
│           ├── recruitment.md     # Recruit real participants
│           └── report-insights.md # Generate and share reports
├── scripts/
│   └── install-mcp.sh            # Universal install script
├── README.md
└── LICENSE
```

## Skill Overview

The **cookiy** skill handles both setup and workflow orchestration in a single package:

- **Setup** — Detects environment, installs the MCP server, handles OAuth, verifies connection
- **Workflows** — Routes user intents to the correct tool chain with enforced sequencing

| Capability | Tools Used |
|---|---|
| **Study Creation** | `cookiy_media_upload` → `cookiy_study_create` → `cookiy_guide_status` → `cookiy_guide_get` |
| **AI Interview** | `cookiy_simulated_interview_generate` → `cookiy_simulated_interview_status` → `cookiy_interview_list` → `cookiy_interview_playback_get` |
| **Guide Editing** | `cookiy_guide_get` → `cookiy_guide_impact` → `cookiy_guide_patch` |
| **Recruitment** | `cookiy_recruit_create` (preview) → `cookiy_recruit_create` (confirm) → `cookiy_recruit_status` |
| **Report & Insights** | `cookiy_report_status` → `cookiy_report_generate` (when allowed) → `cookiy_report_share_link_get` (payment may be required here) |

## Platform Distribution

This single repository serves multiple distribution platforms:

| Platform | What it reads | How users install |
|---|---|---|
| Claude Code Plugins | `.claude-plugin/`, `.mcp.json`, `skills/` | `claude plugin add cookiy-ai/cookiy-skill` |
| skills.sh (Codex, etc.) | `skills/` | `npx skills add cookiy-ai/cookiy-skill` |
| ClawHub (OpenClaw) | `skills/` | `clawhub install cookiy` |
| Cursor Marketplace | `.cursor-plugin/`, `rules/`, `.mcp.json` | Cursor marketplace UI |

## MCP Server

The skill orchestrates [Cookiy's MCP server](https://s-api.cookiy.ai/mcp), which exposes 20 atomic tools for user research operations. The MCP server handles OAuth 2.1 authentication, billing, and all backend operations.

For MCP server installation without skills, see the [cookiy-mcp npm package](https://www.npmjs.com/package/cookiy-mcp).

## License

MIT
