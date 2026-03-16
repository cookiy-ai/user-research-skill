#!/usr/bin/env bash
# Cookiy MCP Server Installer
# Detects the best available package manager and installs the Cookiy CLI,
# then runs it to configure MCP for detected AI clients.
#
# Usage:
#   bash install-mcp.sh              # Interactive: auto-detect clients
#   bash install-mcp.sh -y           # Non-interactive: auto-confirm
#   bash install-mcp.sh --client codex -y   # Target specific client

set -euo pipefail

ARGS=("$@")

main() {
  echo "Cookiy MCP Server Installer"
  echo "==========================="
  echo ""

  # 1. Check if cookiy binary is already installed
  if command -v cookiy &>/dev/null; then
    echo "Cookiy CLI found at: $(command -v cookiy)"
    echo "Running setup..."
    cookiy "${ARGS[@]}"
    exit 0
  fi

  # 2. Try Homebrew (no Node.js required)
  if command -v brew &>/dev/null; then
    echo "Installing via Homebrew (no Node.js required)..."
    brew install cookiy-ai/tap/cookiy
    echo ""
    echo "Running setup..."
    cookiy "${ARGS[@]}"
    exit 0
  fi

  # 3. Try npx (requires Node.js)
  if command -v npx &>/dev/null; then
    echo "Installing via npx..."
    npx cookiy-mcp "${ARGS[@]}"
    exit 0
  fi

  # 4. No supported package manager found
  echo "Error: No supported package manager found."
  echo ""
  echo "Install one of the following:"
  echo ""
  echo "  Homebrew (recommended, no Node.js needed):"
  echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo "    brew install cookiy-ai/tap/cookiy && cookiy"
  echo ""
  echo "  Node.js (v18+):"
  echo "    https://nodejs.org/"
  echo "    npx cookiy-mcp"
  echo ""
  exit 1
}

main
