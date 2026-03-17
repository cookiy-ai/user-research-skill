import { readJsonFile, writeJsonFile } from '../util.mjs';
import { mcpUrl, LEGACY_SERVER_NAMES } from '../config.mjs';

export async function install(serverUrl, serverName, { configPath } = {}) {
  const endpoint = mcpUrl(serverUrl);
  const existing = readJsonFile(configPath) || {};

  if (!existing.servers) existing.servers = {};
  // Remove legacy entries
  for (const name of LEGACY_SERVER_NAMES) delete existing.servers[name];
  existing.servers[serverName] = {
    type: 'sse',
    url: endpoint,
  };

  writeJsonFile(configPath, existing);
  return configPath;
}

export async function remove(serverName, { configPath } = {}) {
  const existing = readJsonFile(configPath);
  if (existing?.servers?.[serverName]) {
    delete existing.servers[serverName];
    writeJsonFile(configPath, existing);
  }
}
