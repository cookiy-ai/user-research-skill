import { mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import crypto from 'node:crypto';
import { c, readJsonFile, writeJsonFile } from './util.mjs';
import {
  fetchOAuthMetadata,
  registerClient,
  generatePKCE,
  buildAuthUrl,
  exchangeCode,
} from './oauth.mjs';
import {
  openBrowser,
  waitForAuthCode,
  findAvailablePort,
  verifyCookiyMcpConnection,
  formatAuthorizationGuidance,
  buildPendingOAuthSession,
  isReusablePendingOAuthSession,
} from './clients/headless-oauth.mjs';

/** Resume file lives next to credentials so the path stays stable under ~/.mcp/cookiy/ */
export const CLI_PENDING_OAUTH_BASENAME = 'pending-oauth-cli.json';

export function defaultCliPendingSessionPath(credentialsPath) {
  return join(dirname(credentialsPath), CLI_PENDING_OAUTH_BASENAME);
}

/**
 * Browser + PKCE OAuth; writes merged credentials to `credentialsPath` (same file `cookiy` reads).
 */
export async function runCookiyCliOAuthLogin({
  serverUrl,
  credentialsPath,
  mcpEndpoint,
  registrationClientName = 'Cookiy CLI (terminal login)',
  verifyClientInfoName = 'cookiy-cli',
  clientLabel = 'Cookiy CLI',
  pendingSessionPath,
} = {}) {
  if (!serverUrl) throw new Error('serverUrl is required');
  if (!credentialsPath) throw new Error('credentialsPath is required');
  if (!mcpEndpoint) throw new Error('mcpEndpoint is required');

  const pendingPath = pendingSessionPath || defaultCliPendingSessionPath(credentialsPath);
  mkdirSync(dirname(credentialsPath), { recursive: true });

  let session = readJsonFile(pendingPath);

  if (isReusablePendingOAuthSession(session, serverUrl)) {
    console.log(`  ${c.yellow('Resume:')} reusing pending OAuth session (${pendingPath})`);
  } else {
    session = null;
    console.log(`  ${c.dim('[0/4]')} Fetching OAuth metadata...`);
    const metadata = await fetchOAuthMetadata(serverUrl);
    const registrationEndpoint = metadata.registration_endpoint;
    if (!registrationEndpoint) {
      throw new Error('Server does not support dynamic client registration');
    }
    console.log(`  ${c.green('OK')} OAuth endpoints discovered`);

    const callbackPort = await findAvailablePort(18247);
    const redirectUri = `http://127.0.0.1:${callbackPort}/callback`;

    console.log(`  ${c.dim('[1/4]')} Registering OAuth client...`);
    const registration = await registerClient(
      registrationEndpoint,
      redirectUri,
      registrationClientName,
    );
    const clientId = registration.client_id;
    console.log(`  ${c.green('OK')} client_id: ${c.dim(clientId)}`);

    console.log(`  ${c.dim('[2/4]')} Generating PKCE challenge...`);
    const { codeVerifier, codeChallenge } = generatePKCE();
    const state = crypto.randomUUID();
    const authUrl = buildAuthUrl(
      metadata.authorization_endpoint,
      clientId,
      redirectUri,
      codeChallenge,
      state,
    );
    console.log(`  ${c.green('OK')} PKCE ready`);

    session = buildPendingOAuthSession({
      clientLabel,
      serverUrl,
      endpoint: mcpEndpoint,
      metadata,
      callbackPort,
      redirectUri,
      clientId,
      codeVerifier,
      codeChallenge,
      state,
      authUrl,
    });
    writeJsonFile(pendingPath, session);
    console.log(`  ${c.green('Saved')} ${c.dim(pendingPath)}`);
  }

  console.log(`  ${c.dim('[3/4]')} Waiting for browser authorization...`);
  console.log();
  console.log('  Opening browser for authorization...');
  const browserOpenResult = await openBrowser(session.auth_url);
  const guidanceLines = formatAuthorizationGuidance({
    clientLabel,
    authUrl: session.auth_url,
    callbackPort: session.callback_port,
    browserOpened: browserOpenResult.opened,
  });
  console.log();
  console.log(`  ${c.bold('Action required:')} ${guidanceLines[0]}`);
  for (const line of guidanceLines.slice(1)) {
    console.log(`  ${c.dim(line)}`);
  }
  if (!browserOpenResult.opened && browserOpenResult.reason) {
    console.log(`  ${c.yellow('Browser auto-open failed:')} ${c.dim(browserOpenResult.reason)}`);
  }
  console.log();
  console.log(
    '  NOTE: If you are an AI agent presenting this URL to a user in a chat app,',
  );
  console.log(
    `  use a markdown link to prevent truncation: [Authorize Cookiy](${session.auth_url})`,
  );
  console.log();
  console.log(`  ${c.dim('Waiting for authorization...')}`);
  console.log(
    `  ${c.dim('Paste the full callback URL or the authorization code, then press Enter:')}`,
  );

  const callbackResult = await waitForAuthCode(session.callback_port, session.state);

  if (callbackResult.state !== session.state) {
    throw new Error('State mismatch: possible CSRF attack. Aborting.');
  }

  console.log(`  ${c.green('OK')} Authorization code received`);

  console.log(`  ${c.dim('[4/4]')} Exchanging code for tokens...`);
  const tokenResponse = await exchangeCode(
    session.token_endpoint,
    callbackResult.code,
    session.client_id,
    session.redirect_uri,
    session.code_verifier,
  );

  if (!tokenResponse.access_token) {
    throw new Error('Token exchange failed: no access_token returned');
  }
  console.log(`  ${c.green('OK')} Tokens received`);

  const prev = readJsonFile(credentialsPath) || {};
  const now = new Date().toISOString();
  const credentials = {
    ...prev,
    server_url: serverUrl,
    mcp_url: mcpEndpoint,
    token_endpoint: session.token_endpoint,
    client_id: session.client_id,
    access_token: tokenResponse.access_token,
    refresh_token: tokenResponse.refresh_token || '',
    token_type: tokenResponse.token_type || 'Bearer',
    updated_at: now,
    created_at: prev.created_at || now,
  };
  writeJsonFile(credentialsPath, credentials);
  console.log(`  ${c.green('Saved')} ${c.dim(credentialsPath)}`);

  rmSync(pendingPath, { force: true });
  console.log(`  ${c.green('Cleared')} ${c.dim(pendingPath)}`);

  console.log(`  ${c.dim('[5/5]')} Verifying Cookiy MCP connection...`);
  await verifyCookiyMcpConnection(mcpEndpoint, credentials.access_token, {
    clientInfoName: verifyClientInfoName,
  });
  console.log(`  ${c.green('OK')} Login complete. Run ${c.cyan('cookiy doctor')} to confirm.`);
  console.log();

  return credentialsPath;
}
