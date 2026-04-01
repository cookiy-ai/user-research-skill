# Cookiy MCP — Cookiy Bootstrap CLI

One-command bootstrap for [Cookiy](https://cookiy.ai) in your AI coding clients.

Cookiy gives your AI agent user-research skills — design interview guides, conduct AI-moderated interviews with real or simulated participants, and generate analysis reports.

This CLI now bootstraps two layers:

1. a local Cookiy skill copy where the client supports local skill folders
2. an MCP connection to Cookiy's live tools

## Quick Start

```bash
npx cookiy-mcp
```

That's it. The CLI auto-detects your installed AI clients, installs a
local Cookiy skill where supported, and then configures MCP.

## macOS Standalone Binary

For a macOS release build, this package can also be compiled into a standalone `cookiy` executable using Node's Single Executable Applications (SEA) flow. This keeps the current npm / `npx cookiy-mcp` path intact while enabling a Homebrew-style binary distribution for macOS.

Build the macOS artifact from this package directory:

```bash
npm install
npm run build:macos
```

If your machine has multiple Node installations and the default one is not SEA-capable, point the build at a specific LTS Node binary:

```bash
COOKIY_SEA_NODE_BINARY="$(which node)" npm run build:macos
```

The build outputs:

- `dist/cookiy` — standalone macOS executable for the current machine architecture
- `dist/cookiy-v<version>-darwin-<arch>.tar.gz` — release artifact suitable for a Homebrew bottle or direct download
- `dist/cookiy-v<version>-darwin-<arch>.tar.gz.sha256` — SHA256 checksum

Recommended Homebrew behavior:

- Install the `cookiy` binary
- Run `cookiy -y` from the formula `post_install` step if you want install-time bootstrap
- Let the CLI install a local Cookiy skill first where supported, then configure MCP
- Leave OAuth completion to first use in clients such as Codex / Claude Code rather than blocking `brew install`
- Keep the default user-facing command on production:
  - `cookiy`

Generate a Homebrew formula after building the macOS artifact:

```bash
npm run build:brew-formula
```

This writes `dist/cookiy.rb`, ready to copy into a Homebrew tap repository.

## Bootstrap Behavior By Client

| Client | Local skill install | MCP install | Notes |
|--------|---------------------|-------------|-------|
| Claude Code | `~/.claude/skills/cookiy` | Automatic via CLI | Skill-first |
| Codex | `~/.agents/skills/cookiy` | Automatic via CLI or TOML fallback | Skill-first |
| OpenClaw | `~/.openclaw/skills/cookiy` | Resumable headless OAuth + script bundle | Skill-first |
| Cursor | Not installed by this CLI | JSON config | MCP-only fallback |
| VS Code (Copilot) | Not installed by this CLI | JSON config | MCP-only fallback |
| Windsurf | Not installed by this CLI | JSON config | MCP-only fallback |
| Cline | Not installed by this CLI | JSON config | MCP-only fallback |
| Manus | Not installed by this CLI | Resumable headless OAuth + script bundle | MCP-only fallback |

## Usage

```bash
# Default (production bootstrap)
npx cookiy-mcp

# Only configure one client
npx cookiy-mcp --client cursor

# OpenClaw (interactive OAuth flow)
npx cookiy-mcp --client openclaw

# Manus / sandbox-friendly headless OAuth flow
npx cookiy-mcp --client manus

# Preview without writing
npx cookiy-mcp --dry-run

# Remove configuration
npx cookiy-mcp --remove

# Skip confirmation
npx cookiy-mcp -y
```

## What You Get After Bootstrap

On supported clients, the CLI installs a local Cookiy skill copy first.
That gives the agent workflow guidance and references before MCP tools
are used.

After that, MCP is configured so the client can call Cookiy's live
tools.

## What You Get — tool groups

Once connected, your AI agent gains these skill modules:

### Discovery
Use these tools when the client needs orientation before entering a workflow.
- `cookiy_introduce` — Explain what Cookiy can do in plain language
- `cookiy_help` — Return atomic MCP tool guidance and recommended chains
- `cookiy_activity_get` — Unified study progress and next-step summary (prefer for “how is recruitment?” / report readiness in natural language)

### Study Creation
Describe your research goal in plain language, and Cookiy creates a complete study with an AI-generated discussion guide.
- `cookiy_study_create` — Create a study asynchronously
- `cookiy_media_upload` — Upload images as study attachments
- `cookiy_guide_status` — Check guide generation status
- `cookiy_guide_get` — Retrieve the guide once ready

### AI Interview
Simulate user interviews with AI personas — no real participants needed. Get preliminary insights in minutes.
- `cookiy_simulated_interview_generate` — Queue AI-to-AI interview simulations
- `cookiy_simulated_interview_status` — Check simulation job progress
- `cookiy_interview_list` — List interviews for a study
- `cookiy_interview_playback_get` — Get transcripts and recordings

### Discussion Guide
Auto-generated interview scripts you can edit. Preview the impact of changes before applying.
- `cookiy_guide_get` — Retrieve the current guide
- `cookiy_guide_impact` — Preview patch impact without saving
- `cookiy_guide_patch` — Apply changes with revision lock
- `cookiy_guide_status` — Check guide generation status

### Recruitment
Recruit real respondents through Cookiy-managed recruitment flows to participate in AI-moderated interviews (including optional quantitative-survey modes when the server exposes them).
- `cookiy_recruit_create` — Launch or reconfigure recruitment
- `cookiy_recruit_status` — Monitor recruitment progress

### Report & Insights
Auto-generate analysis reports from completed interviews. Manage studies and track usage.
- `cookiy_report_status` — Check report readiness
- `cookiy_report_share_link_get` — Return a report share link
- `cookiy_study_get` — Get study summary
- `cookiy_study_list` — List all studies
- `cookiy_balance_get` — Check account balance
- `cookiy_billing_cash_checkout` — Add cash credit (USD cents) via Stripe Checkout before other paid actions

### Quantitative survey (optional)
When the deployment has quantitative survey integration configured:
- `cookiy_quant_survey_list` — List surveys
- `cookiy_quant_survey_create` — Create a questionnaire
- `cookiy_quant_survey_detail` — Public respondent URLs and optional structure
- `cookiy_quant_survey_patch` — Apply safe questionnaire edits
- `cookiy_quant_survey_report` — Default summary/report entrypoint
- `cookiy_quant_survey_results` — Fetch response payloads
- `cookiy_quant_survey_stats` — Legacy compatibility stats view

Recommended quantitative workflow: create or list -> detail -> patch when needed -> report after responses arrive. Use `results` only for raw row exports.

## Example Workflow

After setup, ask your AI agent:

```
"Create a user research study about why users abandon shopping carts"
```

The agent will use Cookiy MCP skills to:
1. Create the study with AI-generated discussion guide
2. Poll `cookiy_guide_status` and load the guide with `cookiy_guide_get`
3. Run interviews or recruitment
4. Poll `cookiy_report_status` while the report is being generated automatically
5. When status is `PREVIEW` or `READY`, call `cookiy_report_share_link_get`

## Options

```
npx cookiy-mcp [server-url] [options]

Arguments:
  server-url              MCP server base URL, or environment alias:
                          prod, dev, dev2, preview, staging, test
                          (default: prod → https://s-api.cookiy.ai)

Options:
  --client <name>         Target specific client
                          (claudeCode, cursor, vscode, codex, windsurf, cline, openclaw, manus)
  --name <server-name>    Override MCP server name (default: cookiy)
  --scope <scope>         Claude Code scope: user|project (default: user)
  --remove                Remove Cookiy MCP config
  --dry-run               Preview changes without writing
  -y, --yes               Skip confirmation
  -h, --help              Show help
  -v, --version           Show version
```

## Requirements

- Node.js >= 18
- A [Cookiy](https://cookiy.ai) account (free to start)

## Headless OAuth Notes

`openclaw` and `manus` use a resumable headless OAuth flow. The installer saves a pending session file before opening the authorization link, so rerunning the same command after a timeout or sandbox restart will reuse the same `client_id`, PKCE verifier, and state instead of creating a new OAuth session.

When the browser can reach the local callback, setup finishes automatically.
If the browser ends on a sandbox-unreachable `127.0.0.1` callback and the
terminal does not continue, paste either the full callback URL or just the
authorization code back into the installer prompt.

After token exchange, the installer verifies the MCP connection with a
lightweight Cookiy tool call and prints a concise success confirmation
instead of requiring a manual raw-JSON verification step.

After a successful exchange, the installer writes:

- `credentials.json` with the OAuth tokens
- `mcp-call.sh` / `mcp-call.ps1` for direct MCP tool calls
- `README.txt` with usage notes

## How It Works

1. Validates the Cookiy MCP server via OAuth discovery endpoint
2. Detects which AI clients are installed on your machine
3. Installs a packaged local Cookiy skill for Codex, Claude Code, and OpenClaw
4. Writes the appropriate MCP configuration for each client
5. Each client handles OAuth login on first use, or completes resumable headless OAuth during setup for OpenClaw / Manus

## Links

- [Cookiy](https://cookiy.ai) — AI-powered user research platform
- [Cookiy Developer Portal](https://cookiy.ai/developer-portal) — API keys and documentation

## License

MIT
