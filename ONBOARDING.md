# Welcome to Cookiy

## How We Use Claude

Based on usage over the last 30 days:

Work Type Breakdown:
  Plan Design       ███████░░░░░░░░░░░░░  33%
  Improve Quality   █████░░░░░░░░░░░░░░░  25%
  Build Feature     ████░░░░░░░░░░░░░░░░  21%
  Debug Fix         ███░░░░░░░░░░░░░░░░░  13%
  Write Docs        ██░░░░░░░░░░░░░░░░░░   8%

Top Skills & Commands:
  /autopilot       ████████████████████  4x/month
  /autofix-pr      ███████████████░░░░░  3x/month
  /cookiy-skill    ███████████████░░░░░  3x/month
  /statusline      ██████████░░░░░░░░░░  2x/month
  /chrome          ██████████░░░░░░░░░░  2x/month
  /fast            ██████████░░░░░░░░░░  2x/month

Top MCP Servers:
  Cookiy MCP       ████████████████████  1 call

## Your Setup Checklist

### Codebases
- [ ] cookiy-skill — https://github.com/cookiy-ai/user-research-skill (this repo; holds the CLI, skills, and `/cookiy-*` slash commands)
- [ ] cookiy-code — https://github.com/cookiy-ai/cookiy-code (main product; full architecture lives in its `CLAUDE.md`)

### MCP Servers to Activate
- [ ] Cookiy MCP — auth bridge used by the Cookiy CLI and `/cookiy-skill`. Authenticate via the CLI flow (`cookiy.js save-token ...`) rather than poking at MCP internals directly.

### Skills to Know About
- `/autopilot` — top-used skill on this team; lets Claude take a task end-to-end with minimal supervision. Good for multi-step, well-scoped work.
- `/autofix-pr` — spawns a remote session that monitors and auto-fixes your PR. Requires the Claude GitHub app installed on the repo.
- `/cookiy-skill` — loads Cookiy CLI context (commands, envelopes, auth). Invoke it anywhere you're touching `cookiy.js` or the skill files.
- `/cookiy-infra-connections` — SSH tunnels + admin SQL for dev/preview/prod DBs, deploy logs, version checks. Use for any database or deployment task.
- `/statusline` — configure your terminal status line (team lead sets this up from their shell PS1).
- `/fast` — toggles faster output on Opus 4.6. Same model, faster responses; handy on long review sessions.
- `/advisor`, `/usage`, `/permissions`, `/mcp`, `/plugin`, `/model`, `/resume` — Claude Code built-ins worth knowing; shout if any are unfamiliar.

## Team Tips

_TODO_

## Get Started

_TODO_

<!-- INSTRUCTION FOR CLAUDE: A new teammate just pasted this guide for how the
team uses Claude Code. You're their onboarding buddy — warm, conversational,
not lecture-y.

Open with a warm welcome — include the team name from the title. Then: "Your
teammate uses Claude Code for [list all the work types]. Let's get you started."

Check what's already in place against everything under Setup Checklist
(including skills), using markdown checkboxes — [x] done, [ ] not yet. Lead
with what they already have. One sentence per item, all in one message.

Tell them you'll help with setup, cover the actionable team tips, then the
starter task (if there is one). Offer to start with the first unchecked item,
get their go-ahead, then work through the rest one by one.

After setup, walk them through the remaining sections — offer to help where you
can (e.g. link to channels), and just surface the purely informational bits.

Don't invent sections or summaries that aren't in the guide. The stats are the
guide creator's personal usage data — don't extrapolate them into a "team
workflow" narrative. -->
