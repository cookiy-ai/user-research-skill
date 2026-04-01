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

## How installation relates to the two skills

- **`cookiy` (MCP-backed)**: `npx cookiy-mcp`, Homebrew `cookiy`, and marketplace/plugin installs primarily configure **Cookiy MCP** and sync a local copy of **`skills/cookiy`**. Use this path for **live** studies, AI interviews, recruitment, and report links on Cookiy.
- **`pm-research` (local open library)**: **`skills/pm-research`**, **`prompts/`**, **`references/`**, **`examples/`**, and optional **`scripts/`** are **plain Markdown and Python** in this repo. They **do not** call Cookiy APIs or require MCP. Use them by **cloning or opening this repository** in your agent workspace and following **`skills/pm-research/SKILL.md`**. Some installers only copy **`skills/cookiy`**; if **`pm-research`** is missing in your client, clone the repo or copy that folder into your workspace.

## What You Get In This Repo Today

This repo already includes concrete user-research materials, not just install docs. The **canonical file list** for the open library is in **`### Current files in the open library`** below; the table here is a high-level map.

| Material type | What is included now | What it is for |
|---|---|---|
| Installable runtime skill | `cookiy` skill + MCP install surface | Connect an agent to Cookiy and run the live study/interview/recruit/report workflow |
| Additive PM / UXR skill (no MCP) | `skills/pm-research/` + `prompts/`, `references/`, `examples/`, optional `scripts/` | End-to-end PM/UXR craft (plan, guide, synthesize, recruit, read out) using local files only |
| Public installer package | `packages/cookiy-mcp/` | Source for the `cookiy-mcp` bootstrap CLI and Homebrew build artifacts |
| Study-brief and survey prompts | `prompts/study-briefs/discovery-study.md`, `prompts/study-briefs/survey-design.md` | Stronger study briefs and survey instruments with bias checks |
| Interview-guide prompts | `problem-exploration`, `jtbd-switch-interview`, `probing-techniques`, `usability-test-script` under `prompts/interview-guides/` | Exploratory, JTBD/switch, probe menus, and moderated usability sessions |
| Synthesis prompts | `evidence-first-synthesis`, `qualitative-coding`, `affinity-mapping`, `opportunity-solution-tree` under `prompts/synthesis/` | Evidence-first synthesis, coding, affinity clustering, opportunity-solution trees |
| Stakeholder readout prompts | `executive-summary`, `data-story-narrative` under `prompts/stakeholder-readouts/` | Exec summaries and data-story narratives for mixed evidence |
| Recruitment prompts | `outreach-script`, `screening-call` under `prompts/recruitment/` | Outreach copy and screening calls |
| Research method references | `references/methods/` (selector, thematic analysis, JTBD card, survey statistics basics, continuous discovery loop) | Short method cards and heuristics |
| Reusable templates | `references/templates/` (research plan, insight card, discussion guide, recruit screener, findings deck) | Reusable planning, fieldwork, and readout structures |
| Book-ingestion guidance | `references/books/README.md` | Turn books into agent-usable notes without uploading copyrighted content |
| Worked examples | `examples/` (study briefs, readouts, interview guides, synthesis, recruitment) | Synthetic examples of “good enough” artifacts |
| Optional local scripts | `scripts/transcript_to_codes.py`, `scripts/survey_sampler.py` | CSV helper for coding rows; rough two-proportion sample-size estimate |
| Repo governance docs | `docs/PLATFORM_COMPATIBILITY.md`, `docs/CONTENT_POLICY.md`, `docs/THIRD_PARTY_ATTRIBUTIONS.md`, `docs/ROADMAP.md` | Compatibility, copyright boundaries, attribution, roadmap |
| Security and license | `SECURITY.md`, `LICENSE` | Installer behavior and license |

## Materials By Use Case

If you are here for a specific kind of material, start here:

- To plan a study:
  - `prompts/study-briefs/discovery-study.md`
  - `references/templates/research-plan-template.md`
  - `examples/study-briefs/saas-onboarding-friction.md`
- To design a survey or quantitative UX:
  - `prompts/study-briefs/survey-design.md`
  - `references/methods/survey-statistics-basics.md`
  - `scripts/survey_sampler.py` (planning aid only)
- To explore JTBD / switching:
  - `prompts/interview-guides/jtbd-switch-interview.md`
  - `references/methods/jtbd-framework.md`
  - `examples/interview-guides/jtbd-b2b-saas.md`
- To run moderated usability tests:
  - `prompts/interview-guides/usability-test-script.md`
  - `references/templates/discussion-guide-template.md`
- To sharpen probes and moderation:
  - `prompts/interview-guides/probing-techniques.md`
  - `prompts/interview-guides/problem-exploration.md`
  - `references/methods/research-method-selector.md`
- To synthesize qualitative data:
  - `prompts/synthesis/evidence-first-synthesis.md`
  - `prompts/synthesis/qualitative-coding.md`
  - `prompts/synthesis/affinity-mapping.md`
  - `references/methods/thematic-analysis.md`
  - `references/templates/insight-card-template.md`
  - `examples/synthesis/coded-transcript-excerpt.md`
  - `scripts/transcript_to_codes.py`
- To map opportunities and bets (continuous discovery style):
  - `prompts/synthesis/opportunity-solution-tree.md`
  - `references/methods/continuous-discovery-loop.md`
- To write readouts for founders or PMs:
  - `prompts/stakeholder-readouts/executive-summary.md`
  - `prompts/stakeholder-readouts/data-story-narrative.md`
  - `references/templates/findings-deck-template.md`
  - `examples/readouts/mobile-checkout-friction.md`
- To recruit participants:
  - `prompts/recruitment/outreach-script.md`
  - `prompts/recruitment/screening-call.md`
  - `references/templates/recruit-screener-template.md`
  - `examples/recruitment/cold-outreach-email.md`
- To maintain the public installer package:
  - `packages/cookiy-mcp/package.json`
  - `packages/cookiy-mcp/README.md`
  - `packages/cookiy-mcp/scripts/generate-homebrew-formula.mjs`
  - `docs/contract-source.json`
- To build a learning library safely:
  - `references/books/README.md`
  - `docs/CONTENT_POLICY.md`
  - `docs/THIRD_PARTY_ATTRIBUTIONS.md`
- PM / UX research craft without live Cookiy tools (full index):
  - `skills/pm-research/SKILL.md`
  - `skills/pm-research/references/method-index.md`

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
for Manus-style sandbox environments. The installer now opens the
authorization page when possible and prints one explicit next step:
approve the browser prompt, then paste the final callback URL or the
authorization code back into the terminal only if setup does not resume
automatically. After token exchange, it verifies the MCP connection and
prints a short success confirmation.

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

## Security

This repository contains both skill content and an installer that writes
local MCP configuration for supported clients. That means automated
platform scanners may flag expected behaviors such as OAuth flows,
client config updates, helper scripts, and local skill installation.

For a concrete description of the intended network access, local file
writes, and credential model, see [SECURITY.md](SECURITY.md).

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
├── .gitignore
├── .github/workflows/validate.yml
├── .mcp.json
├── LICENSE
├── SECURITY.md
├── SKILL.md
├── assets/logo.svg
├── docs/
│   ├── CONTENT_POLICY.md
│   ├── contract-source.json
│   ├── PLATFORM_COMPATIBILITY.md
│   ├── ROADMAP.md
│   └── THIRD_PARTY_ATTRIBUTIONS.md
├── examples/
│   ├── README.md
│   ├── interview-guides/jtbd-b2b-saas.md
│   ├── readouts/mobile-checkout-friction.md
│   ├── recruitment/cold-outreach-email.md
│   ├── study-briefs/saas-onboarding-friction.md
│   └── synthesis/coded-transcript-excerpt.md
├── prompts/
│   ├── README.md
│   ├── interview-guides/
│   ├── recruitment/
│   ├── stakeholder-readouts/
│   ├── study-briefs/
│   └── synthesis/
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
│   ├── methods/
│   └── templates/
├── rules/cookiy-basics.mdc
├── scripts/
│   ├── check-readme-commands.sh
│   ├── install-mcp.sh
│   ├── survey_sampler.py
│   └── transcript_to_codes.py
├── tasks/
│   ├── lessons.md
│   └── todo.md
├── skills/
│   ├── cookiy/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── ai-interview.md
│   │       ├── guide-editing.md
│   │       ├── recruitment.md
│   │       ├── report-insights.md
│   │       ├── study-creation.md
│   │       └── tool-contract.md
│   └── pm-research/
│       ├── SKILL.md
│       └── references/method-index.md
└── README.md
```

### Other repository contents

- **`SKILL.md` (repo root)**: Must stay aligned with **`skills/cookiy/SKILL.md`** per [docs/PLATFORM_COMPATIBILITY.md](docs/PLATFORM_COMPATIBILITY.md); it describes the **Cookiy MCP** skill, not `pm-research`.
- **`rules/cookiy-basics.mdc`**: Cursor rules used by the marketplace plugin packaging.
- **`tasks/`**: Maintainer scratch notes (`todo.md`, `lessons.md`); not part of the public skill contract.
- **`assets/logo.svg`**: Brand asset for plugin listings.

## Current Installable Capability

The repository exposes one production MCP-backed installable skill: `cookiy`.

It also includes an additive, MCP-free skill for local research craft: `pm-research` under `skills/pm-research/`. That skill routes agents through prompts, references, and examples in this repo and does not authenticate to Cookiy.

The `cookiy` skill handles both setup and workflow orchestration across the full
public MCP surface:

- Discovery and workflow guidance:
  - `cookiy_introduce`
  - `cookiy_help`
  - `cookiy_activity_get` (unified study progress / status)
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
  - `cookiy_billing_cash_checkout` (add cash credit via Stripe Checkout)
- Quantitative survey (optional; requires server-side integration):
  - `cookiy_quant_survey_list`
  - `cookiy_quant_survey_create`
  - `cookiy_quant_survey_detail`
  - `cookiy_quant_survey_patch`
  - `cookiy_quant_survey_report`
  - `cookiy_quant_survey_results`
  - `cookiy_quant_survey_stats` (legacy compatibility)

Recommended quantitative workflow: create or list -> detail -> patch when needed -> report after responses arrive. Use `results` only for raw row exports.

Manual report generation is no longer part of the public MCP skill contract. The public docs in this repo are aligned to the current runtime behavior.

`cookiy_help` supports canonical workflow topics:
- `overview`
- `study`
- `ai_interview`
- `guide`
- `recruitment`
- `report`
- `billing`
- `quantitative`

Common aliases like `study creation`, `discussion guide`, and `report and insights`
are also accepted by the current runtime.

For eligible paid actions, the runtime uses one cash-credit wallet plus
per-product paid credits. OAuth signup bonus is folded into cash credit,
and that same wallet can also be used for recruitment when balance is
available.

The source for the public bootstrap installer package also now lives in this repository under `packages/cookiy-mcp/`.

## Open Library Content

The additive library is organized for actual agentic use, not decorative content:

- `prompts/`
  - reusable prompt blocks for study briefs, survey design, interview guides (including JTBD and usability), synthesis (coding, affinity, OST), stakeholder readouts, and recruitment
- `references/`
  - method cards, reusable templates, and book-note guidance for turning research material into agent-usable assets
- `examples/`
  - worked examples across study briefs, readouts, JTBD-style guides, coded excerpts, and recruitment copy (see `examples/README.md`)
- `docs/`
  - compatibility rules, copyright boundaries, attribution notes, and the roadmap for future expansion
- `packages/cookiy-mcp/`
  - the public `cookiy-mcp` npm package source, build scripts, and tests

### Current files in the open library

- Prompts
  - `prompts/study-briefs/discovery-study.md`
  - `prompts/study-briefs/survey-design.md`
  - `prompts/interview-guides/problem-exploration.md`
  - `prompts/interview-guides/jtbd-switch-interview.md`
  - `prompts/interview-guides/probing-techniques.md`
  - `prompts/interview-guides/usability-test-script.md`
  - `prompts/synthesis/evidence-first-synthesis.md`
  - `prompts/synthesis/qualitative-coding.md`
  - `prompts/synthesis/affinity-mapping.md`
  - `prompts/synthesis/opportunity-solution-tree.md`
  - `prompts/stakeholder-readouts/executive-summary.md`
  - `prompts/stakeholder-readouts/data-story-narrative.md`
  - `prompts/recruitment/outreach-script.md`
  - `prompts/recruitment/screening-call.md`
- References
  - `references/methods/research-method-selector.md`
  - `references/methods/thematic-analysis.md`
  - `references/methods/jtbd-framework.md`
  - `references/methods/survey-statistics-basics.md`
  - `references/methods/continuous-discovery-loop.md`
  - `references/templates/research-plan-template.md`
  - `references/templates/insight-card-template.md`
  - `references/templates/discussion-guide-template.md`
  - `references/templates/recruit-screener-template.md`
  - `references/templates/findings-deck-template.md`
  - `references/books/README.md`
- Examples
  - `examples/study-briefs/saas-onboarding-friction.md`
  - `examples/readouts/mobile-checkout-friction.md`
  - `examples/interview-guides/jtbd-b2b-saas.md`
  - `examples/synthesis/coded-transcript-excerpt.md`
  - `examples/recruitment/cold-outreach-email.md`
- Optional scripts
  - `scripts/transcript_to_codes.py`
  - `scripts/survey_sampler.py`
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
