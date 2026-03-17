import { execFileSync } from 'node:child_process';
import { mcpUrl, LEGACY_SERVER_NAMES } from '../config.mjs';
import { readTomlFile, removeTomlSection, upsertTomlMcpServer, writeTomlFile } from '../util.mjs';

export function isExpectedCodexOAuthTimeout(error) {
  return Boolean(
    error
    && typeof error === 'object'
    && (
      error.killed === true
      || error.code === 'ETIMEDOUT'
      || (
        error.signal === 'SIGTERM'
        && typeof error.message === 'string'
        && error.message.toLowerCase().includes('timed out')
      )
    ),
  );
}

export async function install(serverUrl, serverName, { cliPath, configPath } = {}) {
  const endpoint = mcpUrl(serverUrl);

  if (cliPath) {
    // CLI path: use `codex mcp add/remove` commands
    for (const name of [serverName, ...LEGACY_SERVER_NAMES]) {
      try {
        execFileSync(cliPath, ['mcp', 'remove', name], {
          encoding: 'utf8',
          timeout: 15000,
          stdio: ['pipe', 'pipe', 'pipe'],
        });
      } catch {
        // ignore
      }
    }

    try {
      execFileSync(cliPath, ['mcp', 'add', serverName, '--url', endpoint], {
        encoding: 'utf8',
        timeout: 30000,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (err) {
      // Codex registers the MCP server first, then automatically attempts OAuth.
      // The OAuth flow often hangs (waiting for browser callback), causing a timeout.
      // That's OK — the server config is already saved, and Codex will prompt the
      // user to log in via OAuth when they actually use it.
      if (!isExpectedCodexOAuthTimeout(err)) throw err;
    }

    return `codex mcp add ${serverName} --url ${endpoint}`;
  }

  // TOML fallback: write directly to config.toml (App-only, no CLI)
  let content = readTomlFile(configPath);

  // Remove legacy server entries
  for (const name of LEGACY_SERVER_NAMES) {
    content = removeTomlSection(content, `mcp_servers.${name}`);
  }

  content = upsertTomlMcpServer(content, serverName, endpoint);
  writeTomlFile(configPath, content);

  return `wrote ${configPath}`;
}

export async function remove(serverName, { cliPath, configPath } = {}) {
  if (cliPath) {
    execFileSync(cliPath, ['mcp', 'remove', serverName], {
      encoding: 'utf8',
      timeout: 15000,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return;
  }

  // TOML fallback
  let content = readTomlFile(configPath);
  if (content) {
    content = removeTomlSection(content, `mcp_servers.${serverName}`);
    writeTomlFile(configPath, content);
  }
}
