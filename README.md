# Cookiy Skill

Official skill package for [Cookiy](https://cookiy.ai) — AI-powered user research through natural language.

Cookiy gives your AI agent user-research capabilities: create studies, design interview guides, conduct AI-moderated interviews with real or simulated participants, and generate insight reports.

## Quick Install

### Claude Code

Install as a plugin directly in Claude Code:

```bash
claude plugin add cookiy-ai/cookiy-skill
```

Or install the MCP server standalone:

```bash
brew install cookiy-ai/tap/cookiy && cookiy
```

### Codex

```bash
npx skills add cookiy-ai/cookiy-skill
```

Or install the MCP server directly:

```bash
brew install cookiy-ai/tap/cookiy && cookiy --client codex -y
```

### OpenClaw

```bash
clawhub install cookiy-onboard
clawhub install cookiy-workflows
```

Or install the MCP server directly:

```bash
npx cookiy-mcp --client openclaw
```

### Cursor

Install from the [Cursor Marketplace](https://cursor.com/marketplace), or manually:

```bash
npx cookiy-mcp --client cursor -y
```

### Any platform with Node.js

```bash
npx cookiy-mcp
```

The installer auto-detects installed AI clients and configures them.

## What's in this repo

```
cookiy-skill/
├── .claude-plugin/plugin.json     # Claude Code plugin manifest
├── .mcp.json                      # MCP server auto-registration
├── skills/
│   ├── cookiy-onboard/            # Installation & setup skill
│   │   └── SKILL.md
│   └── cookiy-workflows/          # Workflow orchestration skill
│       ├── SKILL.md               # Intent router & universal rules
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

## Skills Overview

### cookiy-onboard

Handles installation, environment detection, OAuth authentication, and first-run verification. Guides the agent through setting up the Cookiy MCP server.

### cookiy-workflows

Routes user intents to the correct tool chain and enforces workflow rules:

| Capability | Tools Used |
|---|---|
| **Study Creation** | `cookiy_media_upload` → `cookiy_study_create` → `cookiy_guide_status` → `cookiy_guide_get` |
| **AI Interview** | `cookiy_simulated_interview_generate` → `cookiy_simulated_interview_status` → `cookiy_interview_list` → `cookiy_interview_playback_get` |
| **Guide Editing** | `cookiy_guide_get` → `cookiy_guide_impact` → `cookiy_guide_patch` |
| **Recruitment** | `cookiy_recruit_create` (preview) → `cookiy_recruit_create` (confirm) → `cookiy_recruit_status` |
| **Report & Insights** | `cookiy_report_status` → `cookiy_report_generate` → `cookiy_report_share_link_get` |

## Platform Distribution

This single repository serves multiple distribution platforms:

| Platform | What it reads | How users install |
|---|---|---|
| Claude Code Plugins | `.claude-plugin/`, `.mcp.json`, `skills/` | `claude plugin add cookiy-ai/cookiy-skill` |
| skills.sh (Codex, etc.) | `skills/` | `npx skills add cookiy-ai/cookiy-skill` |
| ClawHub (OpenClaw) | `skills/` | `clawhub install cookiy-onboard` |
| Cursor Marketplace | Submitted separately | Cursor marketplace UI |

## MCP Server

The skills in this repo orchestrate [Cookiy's MCP server](https://s-api.cookiy.ai/mcp), which exposes 20 atomic tools for user research operations. The MCP server handles OAuth 2.1 authentication, billing, and all backend operations.

For MCP server installation without skills, see the [cookiy-mcp npm package](https://www.npmjs.com/package/cookiy-mcp).

## License

MIT
