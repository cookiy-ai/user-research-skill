# Security

This repository distributes two related surfaces:

- the public `cookiy` skill content
- the `cookiy-mcp` bootstrap CLI that installs local skill files and MCP configuration

The goal of this document is to make the repository's expected security
behavior explicit for reviewers, platform scanners, and users.

## What This Repository Does

At a high level:

- publishes skill documentation and workflow guidance
- bootstraps MCP configuration for supported AI clients
- writes local skill files for clients that support local skill folders
- performs OAuth-based authentication against Cookiy's public MCP server

## Expected Network Access

The public bootstrap flow is expected to talk to:

- `https://s-api.cookiy.ai`
- other explicit Cookiy environment hosts when the user requests them:
  - `https://dev-api.cookiy.ai`
  - `https://dev2-api.cookiy.ai`
  - `https://preview-api.cookiy.ai`
  - `https://staging-api.cookiy.ai`
  - `https://test-api.cookiy.ai`
- standard distribution surfaces such as npm, GitHub, and Homebrew when
  the user chooses those installation paths

The installer validates the target MCP server through OAuth discovery
before writing configuration.

## Expected Local File Writes

The public installer is expected to write only to the local skill and
MCP configuration locations needed by the selected client.

Typical write targets include:

- Codex local skill:
  - `~/.agents/skills/cookiy`
- Claude Code local skill:
  - `~/.claude/skills/cookiy`
- OpenClaw local skill:
  - `~/.openclaw/skills/cookiy`
- Codex MCP config:
  - `~/.codex/config.toml`
- Cursor MCP config:
  - `~/.cursor/mcp.json`
- VS Code MCP config:
  - platform-specific `mcp.json` under the VS Code user config directory
- Windsurf MCP config:
  - `~/.windsurf/mcp.json` or `~/.codeium/windsurf/mcp_config.json`
- Cline MCP config:
  - `~/.cline/mcp_settings.json`
- Headless OAuth bundles for sandbox-style clients:
  - `~/.mcp/<server>/credentials.json`
  - `~/.mcp/<server>/mcp-call.sh`
  - `~/.mcp/<server>/mcp-call.ps1`
  - `~/.mcp/<server>/README.txt`

The installer removes or replaces prior Cookiy MCP entries for the same
client so stale configuration does not linger.

## What It Does Not Intend To Do

This repository is not intended to:

- scan arbitrary files outside the client-specific skill and MCP config paths
- harvest shell history, browser history, API keys, or unrelated secrets
- modify unrelated MCP servers in client config files
- execute hidden background jobs after installation
- bypass OAuth by embedding static production credentials

## Credential Model

Cookiy authentication uses OAuth against the public MCP server.

Expected credential behavior:

- interactive clients may complete OAuth on first use
- headless clients store OAuth tokens in a local `credentials.json`
  bundle under `~/.mcp/<server>/`
- the repository does not ship shared production access tokens

Users should treat local OAuth token files as sensitive machine-local
secrets and avoid copying them across users or machines.

## Why Security Scanners May Flag This Repository

Skill and supply-chain scanners may flag this repository because it
contains patterns that are legitimate for an MCP bootstrapper, including:

- shell-based install instructions
- local config file writes
- OAuth flows
- generated helper scripts that can call MCP endpoints
- client auto-detection logic

These behaviors are expected for the installer surface, but they are
documented here so users can review them explicitly instead of inferring
them from the code.

## Verification Tips

If you want to inspect behavior before running it:

- read:
  - `SKILL.md`
  - `packages/cookiy-mcp/README.md`
  - `packages/cookiy-mcp/lib/skills/local-skill.mjs`
  - `packages/cookiy-mcp/lib/clients/*.mjs`
- preview installer changes with:
  - `npx cookiy-mcp --dry-run`
- target a single client rather than all detected clients:
  - `npx cookiy-mcp --client codex -y`

## Reporting

If you believe you found a real security issue in the public
distribution surface, open a private report through the maintainers'
preferred security channel before publishing exploit details broadly.
