import { execFileSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { mcpUrl, LEGACY_SERVER_NAMES } from '../config.mjs';
import { readJsonFile, writeJsonFile } from '../util.mjs';

/**
 * Remove legacy MCP entries from ~/.claude.json per-project mcpServers.
 * The `claude mcp remove` CLI only handles user-level and .mcp.json scopes,
 * but entries created via the Claude Code UI (/mcp) are stored in
 * ~/.claude.json → projects.<path>.mcpServers — unreachable by CLI.
 */
function cleanPerProjectLegacyEntries(names) {
  const configPath = join(homedir(), '.claude.json');
  const config = readJsonFile(configPath);
  if (!config?.projects) return;

  let dirty = false;
  for (const [, project] of Object.entries(config.projects)) {
    const servers = project.mcpServers;
    if (!servers) continue;
    for (const name of names) {
      if (name in servers) {
        delete servers[name];
        dirty = true;
      }
    }
  }

  if (dirty) {
    writeJsonFile(configPath, config);
  }
}

export async function install(serverUrl, serverName, { scope = 'user', cliPath = 'claude' } = {}) {
  const endpoint = mcpUrl(serverUrl);
  const legacyNames = [serverName, ...LEGACY_SERVER_NAMES];

  // Remove current and legacy entries via CLI (user + project scopes)
  for (const name of legacyNames) {
    for (const s of [scope, ...(scope === 'user' ? ['project'] : ['user'])]) {
      try {
        execFileSync(cliPath, ['mcp', 'remove', name, '-s', s], {
          encoding: 'utf8',
          timeout: 15000,
          stdio: ['pipe', 'pipe', 'pipe'],
        });
      } catch {
        // ignore — entry may not exist in this scope
      }
    }
  }

  // Also clean per-project entries in ~/.claude.json (unreachable by CLI)
  cleanPerProjectLegacyEntries(legacyNames);

  // The CLI may trigger OAuth on add, so allow enough time for authentication.
  execFileSync(cliPath, ['mcp', 'add', serverName, '--transport', 'http', '-s', scope, endpoint], {
    encoding: 'utf8',
    timeout: 120000,
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  return `claude mcp add ${serverName} --transport http -s ${scope} ${endpoint}`;
}

export async function remove(serverName, { scope = 'user', cliPath = 'claude' } = {}) {
  execFileSync(cliPath, ['mcp', 'remove', serverName, '-s', scope], {
    encoding: 'utf8',
    timeout: 15000,
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  // Also clean per-project entries
  cleanPerProjectLegacyEntries([serverName]);
}
