# Platform Compatibility

This repository is consumed by multiple public platforms. Any repo expansion must preserve the current runtime and indexing surface.

## Protected Files

Do not rename, remove, or repurpose these paths without an explicit public-platform migration plan:

- `README.md`
- `SKILL.md`
- `skills/cookiy/SKILL.md`
- `skills/cookiy/references/tool-contract.md`
- `skills/cookiy/references/study-creation.md`
- `skills/cookiy/references/ai-interview.md`
- `skills/cookiy/references/guide-editing.md`
- `skills/cookiy/references/recruitment.md`
- `skills/cookiy/references/report-insights.md`
- `.mcp.json`
- `.claude-plugin/plugin.json`
- `.cursor-plugin/plugin.json`
- `packages/cookiy-mcp/package.json`
- `packages/cookiy-mcp/README.md`
- `packages/cookiy-mcp/bin/`
- `packages/cookiy-mcp/lib/`
- `packages/cookiy-mcp/scripts/`
- `scripts/install-mcp.sh`
- `scripts/check-readme-commands.sh`

## Protected Behaviors

These behaviors are considered part of the current public contract:

- Root skill name remains `cookiy`.
- Root `SKILL.md` and `skills/cookiy/SKILL.md` remain synchronized.
- MCP endpoint remains `https://s-api.cookiy.ai/mcp`.
- npm package source lives in `packages/cookiy-mcp/`.
- The public bootstrap CLI may evolve, but the public install entrypoints remain:
  - `npx cookiy-mcp`
  - `cookiy -y` via Homebrew
- Existing install commands remain valid:
  - `npx skills add cookiy-ai/cookiy-skill`
  - `claude plugin add cookiy-ai/cookiy-skill`
  - `clawhub install cookiy` (skill only; not an MCP install)
  - `npx cookiy-mcp`
  - `npx cookiy-mcp --client <client>`

## Platforms Depending On This Surface

The current public install and discovery surface is used by:

- GitHub skill repository readers
- skills.sh / Skills CLI
- Claude Plugin Marketplace
- Cursor Marketplace
- ClawHub
- Smithery
- npm users of `cookiy-mcp`
- Official MCP Registry and downstream sync targets

ClawHub belongs to the skill-distribution surface. MCP distribution still happens through
`cookiy-mcp`, Homebrew, and Official MCP Registry rather than through `clawhub install`.

## Safe Additions

Additive changes are preferred. These locations are safe for non-runtime expansion:

- `docs/`
- `prompts/`
- `references/`
- `examples/`
- `.github/`

## Risky Changes

Avoid these unless you are explicitly migrating a public platform:

- Renaming `cookiy`
- Moving root files into subdirectories
- Replacing `.mcp.json`
- Changing install commands in public docs without updating the live CLI contract
- Adding new installable skills under `skills/` without checking default-skill behavior on public platforms

## Review Rule

Before merging changes that touch protected files:

1. Check the current public command and endpoint contract.
2. Verify the required files still exist.
3. Verify JSON and shell syntax.
4. Verify the public docs do not advertise capabilities that the live MCP surface no longer exposes.
