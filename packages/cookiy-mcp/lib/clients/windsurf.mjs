import { readJsonFile, writeJsonFile } from '../util.mjs';
import { mcpUrl, LEGACY_SERVER_NAMES } from '../config.mjs';

export async function install(serverUrl, serverName, { configPath } = {}) {
  const endpoint = mcpUrl(serverUrl);
  const existing = readJsonFile(configPath) || {};

  if (!existing.mcpServers) existing.mcpServers = {};
  // Remove legacy entries
  for (const name of LEGACY_SERVER_NAMES) delete existing.mcpServers[name];
  existing.mcpServers[serverName] = {
    serverUrl: endpoint,
  };

  writeJsonFile(configPath, existing);
  return configPath;
}

export async function remove(serverName, { configPath } = {}) {
  const existing = readJsonFile(configPath);
  if (existing?.mcpServers?.[serverName]) {
    delete existing.mcpServers[serverName];
    writeJsonFile(configPath, existing);
  }
}
