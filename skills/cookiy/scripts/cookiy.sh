#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_JS="${COOKIY_CLI_JS:-}"
if [[ -z "$CLI_JS" ]]; then
  for c in \
    "$SCRIPT_DIR/../../../packages/cookiy-mcp/bin/cookiy.mjs" \
    "$SCRIPT_DIR/../../../../bin/cookiy.mjs"
  do
    if [[ -f "$c" ]]; then
      CLI_JS="$c"
      break
    fi
  done
fi
if [[ -z "$CLI_JS" || ! -f "$CLI_JS" ]]; then
  echo "cookiy CLI not found. Set COOKIY_CLI_JS to packages/cookiy-mcp/bin/cookiy.mjs" >&2
  exit 1
fi
exec node "$CLI_JS" "$@"
