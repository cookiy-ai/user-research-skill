import { homedir } from 'node:os';
import { join } from 'node:path';
import { readJsonFile, writeJsonFile } from './util.mjs';
import {
  DEFAULT_SERVER_URL,
  SERVER_NAME,
  resolveApiUrl,
  mcpUrl,
} from './config.mjs';

function formEncode(body) {
  return new URLSearchParams(body).toString();
}

async function httpPostForm(url, body) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: typeof body === 'string' ? body : formEncode(body),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`Token HTTP ${res.status}: ${text || res.statusText}`);
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Token response invalid JSON: ${text}`);
  }
}

export function defaultCredentialsPath() {
  return process.env.COOKIY_CREDENTIALS
    ? process.env.COOKIY_CREDENTIALS
    : join(homedir(), '.mcp', SERVER_NAME, 'credentials.json');
}

export function resolveServerBaseUrl(creds) {
  const raw =
    process.env.COOKIY_SERVER_URL
    || creds?.server_url
    || DEFAULT_SERVER_URL;
  return resolveApiUrl(raw);
}

export function resolveMcpEndpoint(creds, serverBaseUrl) {
  if (process.env.COOKIY_MCP_URL) return process.env.COOKIY_MCP_URL;
  if (creds?.mcp_url) return creds.mcp_url;
  return mcpUrl(serverBaseUrl || resolveServerBaseUrl(creds));
}

export function loadCredentialsFile(credentialsPath) {
  const creds = readJsonFile(credentialsPath);
  if (!creds) {
    throw new Error(
      `Missing credentials at ${credentialsPath}. Set COOKIY_CREDENTIALS or run npx cookiy-mcp for your client to authenticate.`,
    );
  }
  if (!creds.access_token) {
    throw new Error(`No access_token in ${credentialsPath}`);
  }
  return creds;
}

export async function refreshCredentialsFile(credentialsPath, creds) {
  const refresh = creds.refresh_token;
  const clientId = creds.client_id;
  const tokenEndpoint =
    creds.token_endpoint || new URL('/oauth/token', creds.server_url || DEFAULT_SERVER_URL).toString();

  if (!refresh || !clientId) {
    throw new Error('Cannot refresh: missing refresh_token or client_id in credentials');
  }

  const tokenResponse = await httpPostForm(tokenEndpoint, {
    grant_type: 'refresh_token',
    refresh_token: refresh,
    client_id: clientId,
  });

  if (!tokenResponse.access_token) {
    throw new Error('Token refresh failed: no access_token returned');
  }

  const next = {
    ...creds,
    access_token: tokenResponse.access_token,
    refresh_token: tokenResponse.refresh_token || refresh,
    token_type: tokenResponse.token_type || creds.token_type || 'Bearer',
  };

  writeJsonFile(credentialsPath, next);
  return next;
}
