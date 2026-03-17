import {
  installHeadlessOauthClient,
  removeHeadlessOauthClient,
} from './headless-oauth.mjs';

export async function install(serverUrl, serverName, { configPath } = {}) {
  return installHeadlessOauthClient(serverUrl, serverName, {
    configPath,
    clientLabel: 'OpenClaw',
    registrationClientName: 'Cookiy MCP CLI (OpenClaw)',
    callScriptClientInfoName: 'openclaw',
    extraNotes: [
      'OpenClaw uses the generated credentials.json and mcp-call.sh bundle directly.',
      'If the auth flow is interrupted, rerun the same command and the pending session will resume.',
    ],
  });
}

export async function remove(serverName, { configPath } = {}) {
  return removeHeadlessOauthClient(serverName, { configPath });
}
