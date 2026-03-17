import {
  installHeadlessOauthClient,
  removeHeadlessOauthClient,
} from './headless-oauth.mjs';

export async function install(serverUrl, serverName, { configPath } = {}) {
  return installHeadlessOauthClient(serverUrl, serverName, {
    configPath,
    clientLabel: 'Manus',
    registrationClientName: 'Cookiy MCP CLI (Manus)',
    callScriptClientInfoName: 'manus',
    extraNotes: [
      'This mode does not write ~/.mcp/servers.json because Manus may manage that file itself.',
      'Use the generated credentials.json and mcp-call.sh bundle for direct Cookiy MCP calls inside Manus-like sandbox environments.',
      'If the auth flow is interrupted, rerun the same command and the pending session will resume.',
    ],
  });
}

export async function remove(serverName, { configPath } = {}) {
  return removeHeadlessOauthClient(serverName, { configPath });
}
