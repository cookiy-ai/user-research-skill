#!/usr/bin/env bash

set -euo pipefail

# Keep this list aligned with README.md Quick Install and Verification Matrix.
run() {
  echo ""
  echo "+ $*"
  "$@"
}

run npx -y cookiy-mcp --help
run npx -y cookiy-mcp --dry-run -y
run npx -y cookiy-mcp --client claudeCode --dry-run -y
run npx -y cookiy-mcp --client codex --dry-run -y
run npx -y cookiy-mcp --client cursor --dry-run -y
run npx -y cookiy-mcp --client vscode --dry-run -y
run npx -y cookiy-mcp --client openclaw --dry-run -y
run npx -y cookiy-mcp --client windsurf --dry-run -y
run npx -y cookiy-mcp --client cline --dry-run -y
