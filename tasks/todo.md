# Public Repo Quality Pass (2026-03-17)

## Goal

- Improve the public-facing quality of `cookiy-skill` before paid traffic or broader distribution.

## Constraints

- Keep scope minimal: docs, lightweight CI, and repository metadata only.
- Use the live `cookiy-mcp` CLI contract as the source of truth for install commands.
- Avoid adding a heavyweight Node/CI toolchain to a documentation-first repository.

## Approach Notes

- Option A: Docs-only cleanup.
  - Lowest effort, but leaves quality verification weak.
- Option B: Docs + minimal shell/JSON CI.
  - Best fit for this repo: low maintenance, catches broken install guidance early.
- Option C: Full packaging/test harness.
  - Stronger validation, but too heavy for a small distribution repo.

Chosen approach: Option B.

## Edge Cases To Cover

- README install command uses a client alias that the live CLI rejects.
- GitHub Actions runners may not have every supported client installed.
- JSON manifests can drift even in a repo without application code.
- Shell installer may break silently on syntax regressions.
- Verification claims in README must distinguish between locally verified and not recently verified clients.

## Plan

- [x] Fix public install docs to use the live CLI client names.
- [x] Rewrite README top section around one-line value, a 30-second demo, and 3 concrete examples.
- [x] Add a verification matrix with status and last-verified date.
- [x] Add a minimal GitHub Actions workflow for JSON validation, shell syntax checks, and README command dry-runs.
- [x] Update GitHub homepage and repository topics.
- [x] Create the first repository tag/release after the content changes are verified.

## Review

- Fixed the broken Claude Code direct-install docs by switching the public CLI alias from `claude-code` to `claudeCode` in `README.md`, `SKILL.md`, and `skills/cookiy/SKILL.md`.
- Reworked the README top section into a stronger landing page: one-line value proposition, 30-second demo, three concrete prompts, and a verification matrix with 2026-03-17 validation dates.
- Added `scripts/check-readme-commands.sh` plus `.github/workflows/validate.yml` so GitHub Actions now validates JSON manifests, shell syntax, and the direct install commands via `cookiy-mcp --dry-run`.
- Bumped the plugin manifest versions to `1.0.2` in preparation for the first public repository release.
- Updated the GitHub repository homepage to `https://cookiy.ai` and expanded topics to include MCP/client/user-research discovery terms.
- Focused verification completed before release publication:
  - `git diff --check`
  - JSON parse checks for `.mcp.json`, `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`
  - `bash -n scripts/install-mcp.sh`
  - `bash -n scripts/check-readme-commands.sh`
  - `bash scripts/check-readme-commands.sh`
