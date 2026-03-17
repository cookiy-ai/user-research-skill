# Cookiy Skill

Turn Claude Code, Codex, Cursor, VS Code / GitHub Copilot, Windsurf, Cline, OpenClaw, Manus, and other MCP clients into AI user-research operators that can create studies, run interviews, recruit participants, and deliver report links from plain-English prompts.

This repository now has two layers:

- a protected production surface for the current public `cookiy` skill and MCP install flow
- an additive open library of prompts, references, templates, and examples for user research

The install and indexing surface stays stable while the library grows around it.

The public installer package now acts as a bootstrap CLI:

1. on supported clients, it installs a local Cookiy skill copy
2. then it configures MCP
3. on unsupported clients, it falls back to MCP-only setup

## What You Get In This Repo Today

This repo already includes concrete user-research materials, not just install docs.

| Material type | What is included now | What it is for |
|---|---|---|
| Installable runtime skill | `cookiy` skill + MCP install surface | Connect an agent to Cookiy and run the live study/interview/recruit/report workflow |
| Public installer package | `packages/cookiy-mcp/` | Source for the `cookiy-mcp` bootstrap CLI and Homebrew build artifacts |
| Study-brief prompts | `prompts/study-briefs/discovery-study.md` | Turn a vague founder or product question into a stronger study brief |
| Interview-guide prompts | `prompts/interview-guides/problem-exploration.md` | Draft better exploratory interview sections, probes, and evidence goals |
| Synthesis prompts | `prompts/synthesis/evidence-first-synthesis.md` | Convert raw notes, transcripts, survey comments, or support inputs into findings |
| Stakeholder readout prompts | `prompts/stakeholder-readouts/executive-summary.md` | Turn findings into concise founder/PM/stakeholder summaries |
| Research method references | `references/methods/research-method-selector.md`, `references/methods/thematic-analysis.md` | Choose the right method and synthesize qualitative evidence better |
| Reusable templates | `references/templates/research-plan-template.md`, `references/templates/insight-card-template.md` | Standardize research planning and finding documentation |
| Book-ingestion guidance | `references/books/README.md` | Turn books into agent-usable notes without uploading copyrighted content |
| Worked examples | `examples/study-briefs/saas-onboarding-friction.md`, `examples/readouts/mobile-checkout-friction.md` | Show what good study briefs and research readouts look like |
| Repo governance docs | `docs/PLATFORM_COMPATIBILITY.md`, `docs/CONTENT_POLICY.md`, `docs/THIRD_PARTY_ATTRIBUTIONS.md`, `docs/ROADMAP.md` | Keep public platform compatibility stable and define how the library should grow |

## Materials By Use Case

If you are here for a specific kind of material, start here:

- To plan a study:
  - `prompts/study-briefs/discovery-study.md`
  - `references/templates/research-plan-template.md`
  - `examples/study-briefs/saas-onboarding-friction.md`
- To maintain the public installer package:
  - `packages/cookiy-mcp/package.json`
  - `packages/cookiy-mcp/README.md`
  - `packages/cookiy-mcp/scripts/generate-homebrew-formula.mjs`
  - `docs/contract-source.json`
- To write or improve interview guides:
  - `prompts/interview-guides/problem-exploration.md`
  - `references/methods/research-method-selector.md`
- To analyze research data:
  - `prompts/synthesis/evidence-first-synthesis.md`
  - `references/methods/thematic-analysis.md`
  - `references/templates/insight-card-template.md`
- To write readouts for founders or PMs:
  - `prompts/stakeholder-readouts/executive-summary.md`
  - `examples/readouts/mobile-checkout-friction.md`
- To build a learning library safely:
  - `references/books/README.md`
  - `docs/CONTENT_POLICY.md`
  - `docs/THIRD_PARTY_ATTRIBUTIONS.md`

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
clawhub install cookiy  # Skill only, not MCP
```

This installs the Cookiy skill only. To connect OpenClaw to Cookiy's live MCP tools, install the MCP server separately:

Or install the MCP server directly:

```bash
npx cookiy-mcp --client openclaw -y
```

### VS Code / GitHub Copilot

```bash
npx cookiy-mcp --client vscode -y
```

### Windsurf

```bash
npx cookiy-mcp --client windsurf -y
```

### Cline

```bash
npx cookiy-mcp --client cline -y
```

### Manus

```bash
npx cookiy-mcp --client manus -y
```

This writes a resumable headless OAuth helper bundle under `~/.mcp/<server>/`
for Manus-style sandbox environments.

### Cursor

Install from the [Cursor Marketplace](https://cursor.com/marketplace), or manually:

```bash
npx cookiy-mcp --client cursor -y
```

### Any platform with Node.js

```bash
npx cookiy-mcp -y
```

The installer auto-detects installed AI clients. On supported clients, it installs a local Cookiy skill copy first and then configures MCP. Other clients fall back to MCP-only setup.

### macOS with Homebrew

```bash
brew install cookiy-ai/tap/cookiy && cookiy -y
```

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
| Manus | `npx cookiy-mcp --client manus -y` | CLI dry-run verified via forced client selection | 2026-03-17 |

## Public Surface

These install and discovery surfaces remain the protected runtime contract for this repository:

- GitHub skill repo: [cookiy-ai/cookiy-skill](https://github.com/cookiy-ai/cookiy-skill)
- Skills CLI: `npx skills add cookiy-ai/cookiy-skill`
- Claude plugin: `claude plugin add cookiy-ai/cookiy-skill`
- ClawHub skill install: `clawhub install cookiy` (skill only, not MCP)
- npm MCP installer: [cookiy-mcp](https://www.npmjs.com/package/cookiy-mcp)
- Homebrew Tap: [cookiy-ai/homebrew-tap](https://github.com/cookiy-ai/homebrew-tap)
- Official MCP Registry: `ai.cookiy/cookiy`
- MCP endpoint: `https://s-api.cookiy.ai/mcp`

Protected files and compatibility rules are documented in [docs/PLATFORM_COMPATIBILITY.md](docs/PLATFORM_COMPATIBILITY.md).

## What Is In This Repo

```text
cookiy-skill/
├── .claude-plugin/plugin.json
├── .cursor-plugin/plugin.json
├── .github/workflows/validate.yml
├── .mcp.json
├── docs/
│   ├── CONTENT_POLICY.md
│   ├── contract-source.json
│   ├── PLATFORM_COMPATIBILITY.md
│   ├── ROADMAP.md
│   └── THIRD_PARTY_ATTRIBUTIONS.md
├── examples/
│   ├── README.md
│   ├── readouts/mobile-checkout-friction.md
│   └── study-briefs/saas-onboarding-friction.md
├── prompts/
│   ├── README.md
│   ├── interview-guides/problem-exploration.md
│   ├── stakeholder-readouts/executive-summary.md
│   ├── study-briefs/discovery-study.md
│   └── synthesis/evidence-first-synthesis.md
├── packages/
│   └── cookiy-mcp/
│       ├── package.json
│       ├── README.md
│       ├── bin/
│       ├── lib/
│       ├── scripts/
│       └── test/
├── references/
│   ├── README.md
│   ├── books/README.md
│   ├── methods/research-method-selector.md
│   ├── methods/thematic-analysis.md
│   └── templates/
│       ├── insight-card-template.md
│       └── research-plan-template.md
├── rules/cookiy-basics.mdc
├── scripts/
│   ├── check-readme-commands.sh
│   └── install-mcp.sh
├── skills/
│   └── cookiy/
│       ├── SKILL.md
│       └── references/
│           ├── ai-interview.md
│           ├── guide-editing.md
│           ├── recruitment.md
│           ├── report-insights.md
│           ├── study-creation.md
│           └── tool-contract.md
├── SKILL.md
└── README.md
```

## Current Installable Capability

The repository still exposes one production installable skill: `cookiy`.

That skill handles both setup and workflow orchestration across the full
public MCP surface:

- Discovery and workflow guidance:
  - `cookiy_introduce`
  - `cookiy_help`
- Study creation:
  - `cookiy_media_upload`
  - `cookiy_study_create`
  - `cookiy_guide_status`
  - `cookiy_guide_get`
- AI interview:
  - `cookiy_simulated_interview_generate`
  - `cookiy_simulated_interview_status`
  - `cookiy_interview_list`
  - `cookiy_interview_playback_get`
- Guide editing:
  - `cookiy_guide_get`
  - `cookiy_guide_impact`
  - `cookiy_guide_patch`
- Recruitment:
  - `cookiy_recruit_create`
  - `cookiy_recruit_status`
- Report and insights:
  - `cookiy_report_status`
  - `cookiy_report_share_link_get`
  - `cookiy_study_get`
  - `cookiy_study_list`
- Billing and balance:
  - `cookiy_balance_get`

Manual report generation is no longer part of the public MCP skill contract. The public docs in this repo are aligned to the current runtime behavior.

`cookiy_help` supports canonical workflow topics:
- `overview`
- `study`
- `ai_interview`
- `guide`
- `recruitment`
- `report`
- `billing`

Common aliases like `study creation`, `discussion guide`, and `report and insights`
are also accepted by the current runtime.

For eligible paid actions, the runtime may apply `experience_bonus`
before purchased credit. Recruitment is separate and requires paid
credit or cash credit.

The source for the public bootstrap installer package also now lives in this repository under `packages/cookiy-mcp/`.

## Open Library Content

The new additive library is organized for actual agentic use, not decorative content:

- `prompts/`
  - reusable prompt blocks for study briefs, interview-guide drafting, synthesis, and stakeholder readouts
- `references/`
  - method cards, reusable templates, and book-note guidance for turning research material into agent-usable assets
- `examples/`
  - worked examples of a study brief and a synthesis/readout artifact
- `docs/`
  - compatibility rules, copyright boundaries, attribution notes, and the roadmap for future expansion
- `packages/cookiy-mcp/`
  - the public `cookiy-mcp` npm package source, build scripts, and tests

### Current files in the open library

- Prompts
  - `prompts/study-briefs/discovery-study.md`
  - `prompts/interview-guides/problem-exploration.md`
  - `prompts/synthesis/evidence-first-synthesis.md`
  - `prompts/stakeholder-readouts/executive-summary.md`
- References
  - `references/methods/research-method-selector.md`
  - `references/methods/thematic-analysis.md`
  - `references/templates/research-plan-template.md`
  - `references/templates/insight-card-template.md`
  - `references/books/README.md`
- Examples
  - `examples/study-briefs/saas-onboarding-friction.md`
  - `examples/readouts/mobile-checkout-friction.md`
- Public package
  - `packages/cookiy-mcp/package.json`
  - `packages/cookiy-mcp/README.md`
  - `packages/cookiy-mcp/bin/cli.mjs`
  - `packages/cookiy-mcp/lib/*`
  - `packages/cookiy-mcp/scripts/*`
  - `packages/cookiy-mcp/test/*`

## Platform Distribution

This single repository still serves the same public distribution surfaces:

| Platform | What it reads | How users install |
|---|---|---|
| Claude Code Plugins | `.claude-plugin/`, `.mcp.json`, `skills/` | `claude plugin add cookiy-ai/cookiy-skill` |
| skills.sh (Codex, etc.) | `skills/` | `npx skills add cookiy-ai/cookiy-skill` |
| ClawHub (OpenClaw) | `skills/` | `clawhub install cookiy` (skill only; MCP installs separately) |
| Cursor Marketplace | `.cursor-plugin/`, `rules/`, `.mcp.json` | Cursor marketplace UI |

## Future Direction

The roadmap is to keep the installable runtime surface stable while incubating more user-research content and future skills safely.

Planned next areas are tracked in [docs/ROADMAP.md](docs/ROADMAP.md), including:

- research planning
- evidence-first synthesis
- stakeholder readouts
- market and community landscape research

Those future additions will only be promoted into installable skill surfaces after a compatibility review.

## MCP Server

The skill orchestrates [Cookiy's MCP server](https://s-api.cookiy.ai/mcp), which exposes the live user-research tool surface. The MCP server handles OAuth 2.1 authentication, billing, and all backend operations.

For MCP server installation without skills, see the [cookiy-mcp npm package](https://www.npmjs.com/package/cookiy-mcp).

## License

MIT
