---
name: cookiy-onboard
description: >
  Install and configure Cookiy MCP server for AI-powered user research.
  Use when user wants Cookiy research capabilities, when Cookiy MCP tools
  are not available, or when setup and authentication is needed.
  Cookiy enables study creation, AI interviews, participant recruitment,
  and insight report generation through natural language.
---

# Cookiy Onboard

You are helping the user install and configure Cookiy, an AI-powered user
research platform accessible through MCP tools.

## When to activate

- User mentions Cookiy, user research, voice interviews, or participant recruitment
- Any `cookiy_*` tool call fails with a connection or "tool not found" error
- User explicitly asks to set up or connect Cookiy
- User asks what Cookiy can do

## Step 1 — Check if already connected

Try calling `cookiy_introduce`. If it succeeds, Cookiy is already installed.
Skip to Step 4.

If the tool is not found or returns a connection error, proceed to Step 2.

## Step 2 — Install the MCP server

Detect the user's environment and run the appropriate command.

### macOS with Homebrew (recommended — no Node.js required):

```bash
brew install cookiy-ai/tap/cookiy && cookiy
```

### Any platform with Node.js:

```bash
npx cookiy-mcp
```

### Target a specific client:

```bash
# Codex
npx cookiy-mcp --client codex -y

# Claude Code
npx cookiy-mcp --client claude-code -y

# Cursor
npx cookiy-mcp --client cursor -y

# OpenClaw
npx cookiy-mcp --client openclaw -y
```

### Switch environments:

```bash
cookiy dev -y      # Development
cookiy preview -y  # Preview / staging
cookiy -y          # Production (default)
```

The installer auto-detects installed AI clients and configures them.
It will prompt for OAuth authentication during setup.

## Step 3 — Verify the connection

After installation completes, call `cookiy_introduce` to confirm the
MCP server is connected and authenticated.

If authentication fails:
- Re-run the install command. Do NOT remove and reinstall the server.
- The OAuth token may have expired. The installer handles re-authentication.

## Step 4 — Orient the user

Once connected, present Cookiy's five capability modules:

1. **Study Creation** — Describe a research goal and get an AI-generated
   discussion guide.
2. **AI Interview** — Simulate interviews with AI personas for quick insights.
3. **Discussion Guide** — Review and edit the interview script before going live.
4. **Recruitment** — Recruit real participants for AI-moderated interviews.
5. **Report & Insights** — Generate analysis reports and shareable links.

Present these as named modules in plain language. Do not expose raw tool
names to the user.

Call `cookiy_help` with a topic parameter if the user wants guidance on a
specific workflow.

## After onboarding

Hand off to the **cookiy-workflows** skill for all subsequent Cookiy tasks.
All research operations go through Cookiy MCP tools — never guess
undocumented REST paths or construct URLs manually.
