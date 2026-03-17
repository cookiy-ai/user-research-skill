# Public Repo Open Library Expansion Plan (2026-03-17)

## Goal

- Expand `cookiy-skill` from a pure MCP install/workflow repo into a broader open user-research library.
- Keep the current public install and indexing surfaces stable for every platform documented in `/Users/yupeng/Documents/Obsidian Vault/对外开发者api/对外暴露平台/总结.md`.
- Align drifted public docs with the current live MCP contract.

## Protected Compatibility Surface

These paths and behaviors must remain valid because current public platforms depend on them:

- `README.md`
- `SKILL.md`
- `skills/cookiy/SKILL.md`
- `skills/cookiy/references/*.md`
- `.mcp.json`
- `.claude-plugin/plugin.json`
- `.cursor-plugin/plugin.json`
- `scripts/install-mcp.sh`
- `scripts/check-readme-commands.sh`
- Root skill name remains `cookiy`
- MCP endpoint remains `https://s-api.cookiy.ai/mcp`
- Existing install commands remain unchanged:
  - `npx skills add cookiy-ai/cookiy-skill`
  - `claude plugin add cookiy-ai/cookiy-skill`
  - `clawhub install cookiy`
  - `npx cookiy-mcp`

## Relevant Fundamentals

- Distribution surface stability matters more than repository neatness when third-party indexers cache file paths and default entrypoints.
- Additive repository changes are safer than structural replacement when multiple marketplaces consume the same repo.
- Documentation repos still need contract validation because public docs can drift faster than code.
- Open content repos need a clear copyright boundary when prompts, references, and book-derived material are added.

## Approach Comparison

- Option A: Additive library expansion outside the protected runtime surface.
  - Pros: Lowest platform risk, keeps current indexing behavior, easy to validate.
  - Cons: New research content is not immediately exposed as installable skills.
- Option B: Multi-skill expansion under `skills/`.
  - Pros: More visible skill catalog inside the repo.
  - Cons: Higher risk for default-skill resolution and marketplace/index drift.
- Option C: Split learning content into a separate repo.
  - Pros: Clean separation of concerns.
  - Cons: Loses consolidation and creates extra maintenance overhead.

Chosen approach: Option A.

## Edge Cases To Cover

- Skills CLI, Smithery, or plugin surfaces may assume the root `cookiy` skill is the default entrypoint.
- Moving or renaming `.mcp.json`, root `SKILL.md`, or plugin manifests can break installation or indexing.
- Public docs still mention `cookiy_report_generate`, but MCP no longer exposes manual report generation.
- Future contributors may accidentally add copyrighted book excerpts instead of transformed notes.
- Additive library content should not imply that new installable skills are already supported on all public platforms.

## Plan

- [x] Replace the repo top-level README so it clearly separates protected runtime surfaces from the new open library layer.
- [x] Add compatibility and content-policy docs so future edits do not break public platforms or copyright boundaries.
- [x] Add substantive prompts, methods, templates, book-note guidance, and examples under additive top-level directories.
- [x] Align the existing report-related public docs with the live MCP contract by removing manual `cookiy_report_generate` guidance.
- [x] Extend the lightweight GitHub Actions validation to protect the public surface.
- [ ] Run focused validation and record the final review.

## Review

- Kept the protected public install and indexing surface intact:
  - `README.md`
  - `SKILL.md`
  - `skills/cookiy/SKILL.md`
  - `skills/cookiy/references/*.md`
  - `.mcp.json`
  - `.claude-plugin/plugin.json`
  - `.cursor-plugin/plugin.json`
  - `scripts/install-mcp.sh`
  - `scripts/check-readme-commands.sh`
- Expanded the repo with additive open-library layers only:
  - `docs/`
  - `prompts/`
  - `references/`
  - `examples/`
- Rewrote `README.md` so the repo now clearly presents:
  - the stable public runtime surface
  - the new open library purpose
  - the new repo structure
  - the unchanged install paths
- Added compatibility and governance docs:
  - `docs/PLATFORM_COMPATIBILITY.md`
  - `docs/CONTENT_POLICY.md`
  - `docs/THIRD_PARTY_ATTRIBUTIONS.md`
  - `docs/ROADMAP.md`
- Added agent-usable content:
  - 4 prompt files
  - 4 reference files plus book-ingestion guidance
  - 2 worked examples
- Aligned the public report workflow to the current MCP contract by removing manual `cookiy_report_generate` guidance from:
  - `README.md`
  - `skills/cookiy/references/tool-contract.md`
  - `skills/cookiy/references/report-insights.md`
- Extended `.github/workflows/validate.yml` to guard the public surface and prevent manual report-generation drift from reappearing.
- Focused validation passed:
  - `git diff --check`
  - JSON parse checks for `.mcp.json`, `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`
  - `bash -n scripts/install-mcp.sh`
  - `bash -n scripts/check-readme-commands.sh`
  - `bash scripts/check-readme-commands.sh`
  - root `SKILL.md` and `skills/cookiy/SKILL.md` sync check
  - MCP endpoint contract check against `.mcp.json`

# Public Installer Package Migration Plan (2026-03-17)

- [x] Audit `packages/tools/cookiy-mcp-setup` before moving it into this public repo.
- [x] Copy the public installer package into `packages/cookiy-mcp` without bringing build artifacts, local settings, or dependencies.
- [x] Add `docs/contract-source.json` so this repo records which `cookiy-code` runtime contract commit it mirrors.
- [x] Update the root README so the public package source is discoverable.
- [x] Run focused validation and record the migration review.

## Review

- Leakage audit outcome before migration:
  - safe to move: `README.md`, `package*.json`, `bin/`, `lib/`, `scripts/`, `test/`
  - intentionally not moved: `dist/`, `node_modules/`, `.claude/settings.local.json`, `skills-lock.json`
  - no secrets were found in the moved source tree
- Moved the public installer package into `packages/cookiy-mcp/` in the public repo.
- Added `packages/cookiy-mcp/.gitignore` so local package installs/builds do not pollute the public repo with `node_modules/`, `dist/`, or `.claude/`.
- Added `docs/contract-source.json` pointing at `cookiy-code/docs/public-mcp-contract.json` and the source commit used for this migration.
- Updated `README.md` and `docs/PLATFORM_COMPATIBILITY.md` so the npm package source is now treated as part of the protected public distribution surface.
- Focused validation passed:
  - `git diff --check`
  - JSON parse checks for `.mcp.json`, plugin manifests, and `docs/contract-source.json`
  - `bash -n scripts/install-mcp.sh`
  - `bash -n scripts/check-readme-commands.sh`
  - `npm test` in `packages/cookiy-mcp`
  - `node ./bin/cli.mjs --client manus --dry-run -y` in `packages/cookiy-mcp`
  - `npm pack --dry-run` in `packages/cookiy-mcp`

# External Platform Doc Drift Fix (2026-03-17)

## Goal

- Align `/Users/yupeng/Documents/Obsidian Vault/对外开发者api/对外暴露平台/总结.md` with the current public installer and repo docs.

## Drift To Fix

- Add `Manus` to the externally documented supported client list and MCP install commands.
- Correct the Claude Code client flag from `claude-code` to `claudeCode`.
- Refresh the doc date so the external summary reflects the current 2026-03-17 installer surface.

## Plan

- [x] Update the external Obsidian platform summary note.
- [x] Verify the revised commands and supported-client list against `README.md`, `SKILL.md`, and `packages/cookiy-mcp/bin/cli.mjs`.
- [x] Record the review outcome here.

## Review

- Updated `/Users/yupeng/Documents/Obsidian Vault/对外开发者api/对外暴露平台/总结.md` to match the current 2026-03-17 installer surface.
- Fixed the documented Claude Code MCP command from `--client claude-code` to `--client claudeCode`.
- Added `Manus` in:
  - the supported client table
  - the platform entry overview
  - the MCP install command list
- Repaired the malformed `OpenClaw` support-row table structure while editing the same section.
- Removed the hardcoded Official MCP Registry version from the discovery table and replaced it with a stable “latest API 为准” note to reduce future doc drift.
- Targeted verification passed via direct content comparison against:
  - `README.md`
  - `SKILL.md`
  - `packages/cookiy-mcp/bin/cli.mjs`
  - grep check confirming the external note now contains `claudeCode` and `manus`, with no remaining `claude-code`.
