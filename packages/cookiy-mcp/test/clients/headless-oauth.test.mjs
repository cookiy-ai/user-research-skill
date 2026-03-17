import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildPendingOAuthSession,
  generateInstallNotes,
  generateMcpCallScript,
  generateMcpCallScriptPowerShell,
  isReusablePendingOAuthSession,
  resolveHeadlessWorkspacePaths,
} from '../../lib/clients/headless-oauth.mjs';
import { detectClients } from '../../lib/detect.mjs';

test('resolves workspace paths for unix and windows headless clients', () => {
  const unixPaths = resolveHeadlessWorkspacePaths('/tmp/cookiy', 'cookiy', 'linux');
  assert.equal(unixPaths.workspaceDir, '/tmp/cookiy/cookiy');
  assert.equal(unixPaths.scriptName, 'mcp-call.sh');
  assert.equal(unixPaths.pendingSessionPath, '/tmp/cookiy/cookiy/pending-oauth.json');

  const windowsPaths = resolveHeadlessWorkspacePaths('C:\\cookiy', 'cookiy', 'win32');
  assert.equal(windowsPaths.scriptName, 'mcp-call.ps1');
  assert.match(windowsPaths.scriptPath, /mcp-call\.ps1$/);
});

test('pending OAuth sessions are reusable only when required fields are present', () => {
  const session = buildPendingOAuthSession({
    clientLabel: 'Manus',
    serverUrl: 'https://s-api.cookiy.ai',
    endpoint: 'https://s-api.cookiy.ai/mcp',
    metadata: {
      authorization_endpoint: 'https://s-api.cookiy.ai/oauth/authorize',
      token_endpoint: 'https://s-api.cookiy.ai/oauth/token',
      registration_endpoint: 'https://s-api.cookiy.ai/oauth/register',
    },
    callbackPort: 18247,
    redirectUri: 'http://127.0.0.1:18247/callback',
    clientId: 'client-123',
    codeVerifier: 'verifier',
    codeChallenge: 'challenge',
    state: 'state-123',
    authUrl: 'https://s-api.cookiy.ai/oauth/authorize?...',
  });

  assert.equal(isReusablePendingOAuthSession(session, 'https://s-api.cookiy.ai'), true);
  assert.equal(isReusablePendingOAuthSession({ ...session, client_id: '' }, 'https://s-api.cookiy.ai'), false);
  assert.equal(isReusablePendingOAuthSession(session, 'https://preview-api.cookiy.ai'), false);
});

test('generated shell helper embeds the caller identity and refresh flow', () => {
  const script = generateMcpCallScript(
    'https://s-api.cookiy.ai',
    'https://s-api.cookiy.ai/mcp',
    '/tmp/cookiy/credentials.json',
    { clientInfoName: 'manus' },
  );

  assert.match(script, /"name":"manus"/);
  assert.match(script, /grant_type=refresh_token/);
  assert.match(script, /credentials\.json/);
});

test('generated powershell helper embeds the caller identity and refresh flow', () => {
  const script = generateMcpCallScriptPowerShell(
    'https://s-api.cookiy.ai',
    'https://s-api.cookiy.ai/mcp',
    'C:\\cookiy\\credentials.json',
    { clientInfoName: 'openclaw' },
  );

  assert.match(script, /"name":"openclaw"/);
  assert.match(script, /grant_type=refresh_token/);
  assert.match(script, /credentials\.json/);
});

test('install notes call out resume-safe behavior and Manus managed config caveat', () => {
  const notes = generateInstallNotes({
    clientLabel: 'Manus',
    serverUrl: 'https://s-api.cookiy.ai',
    endpoint: 'https://s-api.cookiy.ai/mcp',
    credentialsPath: '/tmp/cookiy/credentials.json',
    scriptPath: '/tmp/cookiy/mcp-call.sh',
    pendingSessionPath: '/tmp/cookiy/pending-oauth.json',
    extraNotes: [
      'This mode does not write ~/.mcp/servers.json because Manus may manage that file itself.',
    ],
  });

  assert.match(notes, /resume from the pending session file/i);
  assert.match(notes, /servers\.json/i);
  assert.match(notes, /mcp-call\.sh/);
});

test('detectClients always exposes a Manus entry', () => {
  const clients = detectClients();
  assert.ok(clients.manus);
  assert.equal(clients.manus.key, 'manus');
  assert.equal(clients.manus.method, 'oauth');
  assert.equal(typeof clients.manus.configPath, 'string');
});
