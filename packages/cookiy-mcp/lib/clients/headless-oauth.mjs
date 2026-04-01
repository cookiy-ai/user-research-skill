import { mkdirSync, writeFileSync, rmSync, existsSync, chmodSync } from 'node:fs';
import { join } from 'node:path';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import readline from 'node:readline';
import crypto from 'node:crypto';
import https from 'node:https';
import http from 'node:http';
import { c, readJsonFile, writeJsonFile } from '../util.mjs';
import { mcpUrl, LEGACY_SERVER_NAMES } from '../config.mjs';
import {
  fetchOAuthMetadata,
  registerClient,
  generatePKCE,
  buildAuthUrl,
  exchangeCode,
} from '../oauth.mjs';

export const PENDING_OAUTH_FILE_NAME = 'pending-oauth.json';
export const INSTALL_NOTES_FILE_NAME = 'README.txt';

function renderCallbackPage(success, errorMessage, authCode) {
  const title = success ? 'Authorization Successful' : 'Authorization Failed';
  const iconColor = success ? '#15803d' : '#b91c1c';
  const iconPath = success
    ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>'
    : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>';

  const codeBlock = success && authCode
    ? `<p style="margin-top:16px;color:#606060;font-size:14px;">If the terminal did not complete automatically, copy this code and paste it into the terminal:</p>
<div class="code-box">
  <code id="auth-code">${authCode}</code>
  <button onclick="copyCode()" id="copy-btn" title="Copy code">
    <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
  </button>
</div>
<script>
function copyCode(){
  var code=document.getElementById('auth-code').textContent;
  navigator.clipboard.writeText(code).then(function(){
    var btn=document.getElementById('copy-btn');
    btn.innerHTML='<svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>';
    setTimeout(function(){btn.innerHTML='<svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" fill="none" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>';},2000);
  });
}
</script>`
    : '';

  const message = success
    ? 'You can close this tab and return to the terminal.'
    : `Error: ${errorMessage || 'Unknown error'}`;

  return `<!doctype html>
<html><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title} - Cookiy</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700&display=swap" rel="stylesheet">
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Inter',-apple-system,BlinkMacSystemFont,sans-serif;background:#fff;color:#1a1615;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden}
.bg{position:absolute;width:700px;height:700px;background:rgba(249,230,197,0.4);border-radius:50%;filter:blur(150px);top:-200px;left:50%;transform:translateX(-50%);pointer-events:none}
.card{position:relative;z-index:10;text-align:center;max-width:480px;padding:40px 24px}
.icon{width:64px;height:64px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:24px;background:${success ? 'rgba(21,128,61,0.1)' : 'rgba(185,28,28,0.1)'}}
.icon svg{width:32px;height:32px;stroke:${iconColor};fill:none}
h1{font-size:24px;font-weight:500;margin-bottom:8px}
p{font-size:15px;color:#606060;line-height:22px}
.logo{position:absolute;top:24px;left:32px;font-size:20px;font-weight:700;color:#18181b;letter-spacing:-0.5px}
.code-box{display:flex;align-items:center;gap:8px;margin-top:12px;padding:10px 14px;background:#f5f5f4;border:1px solid #e7e5e4;border-radius:8px;font-family:'SF Mono',SFMono-Regular,Consolas,'Liberation Mono',Menlo,monospace}
.code-box code{flex:1;font-size:13px;word-break:break-all;text-align:left;color:#1a1615;user-select:all}
.code-box button{flex-shrink:0;background:none;border:1px solid #d6d3d1;border-radius:6px;padding:6px;cursor:pointer;color:#78716c;transition:color .15s,border-color .15s}
.code-box button:hover{color:#1a1615;border-color:#a8a29e}
</style></head><body>
<div class="bg"></div>
<div class="logo">Cookiy</div>
<div class="card">
<div class="icon"><svg viewBox="0 0 24 24">${iconPath}</svg></div>
<h1>${title}</h1>
<p>${message}</p>
${codeBlock}
</div>
</body></html>`;
}

export function buildBrowserOpenCommand(url, platform = process.platform) {
  if (platform === 'darwin') {
    return { command: 'open', args: [url] };
  }
  if (platform === 'win32') {
    return { command: 'cmd', args: ['/c', 'start', '', url] };
  }
  return { command: 'xdg-open', args: [url] };
}

export function formatAuthorizationGuidance({
  clientLabel,
  authUrl,
  callbackPort,
  browserOpened,
}) {
  const callbackUrl = `http://127.0.0.1:${callbackPort}/callback`;
  const browserLine = browserOpened
    ? 'The authorization page should already be opening in your browser.'
    : 'Open the authorization link below in your browser to continue.';

  return [
    `${clientLabel} authorization needs one quick step in the browser.`,
    browserLine,
    `Authorize Cookiy: ${authUrl}`,
    `After approval, setup will continue automatically if the browser can reach ${callbackUrl}.`,
    'If the terminal does not continue within a few seconds, paste the full callback URL or just the code here and press Enter.',
  ];
}

function postJsonRpc(endpoint, payload, accessToken) {
  const parsedUrl = new URL(endpoint);
  const client = parsedUrl.protocol === 'https:' ? https : http;
  const body = JSON.stringify(payload);

  return new Promise((resolve, reject) => {
    const req = client.request(parsedUrl, {
      method: 'POST',
      timeout: 15000,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        Authorization: `Bearer ${accessToken}`,
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        if (res.statusCode >= 400) {
          reject(new Error(`MCP HTTP ${res.statusCode}: ${data}`));
          return;
        }
        if (data.trim() === '') {
          resolve({});
          return;
        }
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error(`MCP returned invalid JSON: ${data}`));
        }
      });
    });

    req.on('error', (err) => reject(new Error(`MCP request failed: ${err.message}`)));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('MCP request timed out'));
    });

    req.write(body);
    req.end();
  });
}

export async function verifyCookiyMcpConnection(endpoint, accessToken, {
  clientInfoName = 'headless-oauth',
} = {}) {
  const initializeResponse = await postJsonRpc(endpoint, {
    jsonrpc: '2.0',
    id: 1,
    method: 'initialize',
    params: {
      protocolVersion: '2025-03-26',
      capabilities: {},
      clientInfo: {
        name: clientInfoName,
        version: '1.0.0',
      },
    },
  }, accessToken);

  if (initializeResponse.error) {
    throw new Error(`MCP initialize failed: ${initializeResponse.error.message || 'unknown error'}`);
  }

  await postJsonRpc(endpoint, {
    jsonrpc: '2.0',
    method: 'notifications/initialized',
  }, accessToken);

  const toolResponse = await postJsonRpc(endpoint, {
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/call',
    params: {
      name: 'cookiy_introduce',
      arguments: {},
    },
  }, accessToken);

  if (toolResponse.error) {
    throw new Error(`Cookiy verification failed: ${toolResponse.error.message || 'unknown error'}`);
  }

  const structuredContent = toolResponse.result?.structuredContent;
  if (structuredContent?.ok === false) {
    throw new Error('Cookiy verification failed: introduce returned ok=false');
  }

  return true;
}

export async function openBrowser(url) {
  const { command, args } = buildBrowserOpenCommand(url);

  return new Promise((resolve) => {
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      resolve(result);
    };

    let child;
    try {
      child = spawn(command, args, { detached: true, stdio: 'ignore' });
    } catch (err) {
      finish({ opened: false, reason: err.message });
      return;
    }

    child.on('error', (err) => {
      finish({ opened: false, reason: err.message });
    });
    child.on('exit', (code) => {
      if (typeof code === 'number' && code !== 0) {
        finish({ opened: false, reason: `exit code ${code}` });
      }
    });
    child.unref();

    setTimeout(() => {
      finish({ opened: true });
    }, 150);
  });
}

function closeServer(server) {
  try {
    if (server.listening) server.close();
  } catch {
    // ignore
  }
}

export function waitForAuthCode(port, expectedState) {
  return new Promise((resolve, reject) => {
    let settled = false;
    let serverFailed = false;

    function finish(result, error) {
      if (settled) return;
      settled = true;
      closeServer(server);
      rl.close();
      if (error) reject(error);
      else resolve(result);
    }

    const server = createServer((req, res) => {
      const url = new URL(req.url, `http://127.0.0.1:${port}`);
      const code = url.searchParams.get('code');
      const state = url.searchParams.get('state');
      const error = url.searchParams.get('error');

      if (error) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(renderCallbackPage(false, error));
        finish(null, new Error(`Authorization failed: ${error}`));
        return;
      }

      if (code) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(renderCallbackPage(true, null, code));
        finish({ code, state });
        return;
      }

      res.writeHead(400, { 'Content-Type': 'text/plain' });
      res.end('Missing authorization code');
    });

    server.on('error', (err) => {
      serverFailed = true;
      console.log(
        `  ${c.yellow('Warning:')} local callback server unavailable on port ${port} (${err.message}).`,
      );
      console.log(
        `  ${c.dim('Continue by copying the full callback URL or code from the browser back into this terminal.')}`,
      );
    });

    server.listen(port, '127.0.0.1', () => {
      if (serverFailed) return;
      console.log(`  ${c.dim(`Listening for OAuth callback on http://127.0.0.1:${port}/callback`)}`);
    });

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    const askLine = () => {
      rl.question('', (input) => {
        if (settled) return;
        const trimmed = (input || '').trim();
        if (!trimmed) {
          askLine();
          return;
        }

        let code;
        let state;
        try {
          const url = new URL(trimmed);
          code = url.searchParams.get('code');
          state = url.searchParams.get('state');
        } catch {
          code = trimmed;
          state = expectedState;
        }

        if (code) {
          finish({ code, state: state || expectedState });
        } else {
          askLine();
        }
      });
    };

    askLine();
  });
}

export function findAvailablePort(startPort) {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.listen(startPort, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
    server.on('error', () => {
      if (startPort < 65535) {
        resolve(findAvailablePort(startPort + 1));
      } else {
        reject(new Error('No available port found'));
      }
    });
  });
}

export function resolveHeadlessWorkspacePaths(
  configPath,
  serverName,
  platform = process.platform,
) {
  const isWindows = platform === 'win32';
  const workspaceDir = join(configPath, serverName);
  const scriptName = isWindows ? 'mcp-call.ps1' : 'mcp-call.sh';
  return {
    workspaceDir,
    credentialsPath: join(workspaceDir, 'credentials.json'),
    pendingSessionPath: join(workspaceDir, PENDING_OAUTH_FILE_NAME),
    notesPath: join(workspaceDir, INSTALL_NOTES_FILE_NAME),
    scriptName,
    scriptPath: join(workspaceDir, scriptName),
  };
}

export function isReusablePendingOAuthSession(session, serverUrl) {
  return Boolean(
    session
      && session.server_url === serverUrl
      && session.authorization_endpoint
      && session.token_endpoint
      && session.client_id
      && session.redirect_uri
      && session.code_verifier
      && session.state
      && session.auth_url
      && Number.isInteger(session.callback_port),
  );
}

export function buildPendingOAuthSession({
  clientLabel,
  serverUrl,
  endpoint,
  metadata,
  callbackPort,
  redirectUri,
  clientId,
  codeVerifier,
  codeChallenge,
  state,
  authUrl,
}) {
  return {
    version: 1,
    client_label: clientLabel,
    server_url: serverUrl,
    mcp_url: endpoint,
    authorization_endpoint: metadata.authorization_endpoint,
    token_endpoint: metadata.token_endpoint,
    registration_endpoint: metadata.registration_endpoint,
    callback_port: callbackPort,
    redirect_uri: redirectUri,
    client_id: clientId,
    code_verifier: codeVerifier,
    code_challenge: codeChallenge,
    state,
    auth_url: authUrl,
    created_at: new Date().toISOString(),
  };
}

export function generateInstallNotes({
  clientLabel,
  serverUrl,
  endpoint,
  credentialsPath,
  scriptPath,
  pendingSessionPath,
  extraNotes = [],
}) {
  const notes = [
    `Cookiy ${clientLabel} MCP helper files`,
    '',
    `Server URL: ${serverUrl}`,
    `MCP endpoint: ${endpoint}`,
    `Credentials: ${credentialsPath}`,
    `Call script: ${scriptPath}`,
    `Pending OAuth session: ${pendingSessionPath}`,
    '',
    'If the OAuth flow is interrupted before token exchange finishes, rerun the same',
    'cookiy-mcp command and it will resume from the pending session file instead of',
    'registering a new client or generating a new PKCE verifier.',
    '',
    'Direct tool call example:',
    `  ${scriptPath} cookiy_help '{"topic":"overview"}'`,
  ];

  if (extraNotes.length > 0) {
    notes.push('', ...extraNotes);
  }

  return `${notes.join('\n')}\n`;
}

export function generateMcpCallScript(
  serverUrl,
  mcpEndpoint,
  credentialsPath,
  { clientInfoName = 'headless-oauth' } = {},
) {
  return `#!/usr/bin/env bash
# Cookiy MCP call script
# Generated by cookiy-mcp CLI
# Usage: ./mcp-call.sh <tool_name> '<json_arguments>'

set -euo pipefail

CREDENTIALS_FILE="${credentialsPath}"
MCP_ENDPOINT="${mcpEndpoint}"
SERVER_URL="${serverUrl}"

read_credentials() {
  if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Error: credentials.json not found at $CREDENTIALS_FILE" >&2
    exit 1
  fi
  ACCESS_TOKEN=$(python3 -c "import json; d=json.load(open('$CREDENTIALS_FILE')); print(d['access_token'])")
  REFRESH_TOKEN=$(python3 -c "import json; d=json.load(open('$CREDENTIALS_FILE')); print(d.get('refresh_token',''))")
  CLIENT_ID=$(python3 -c "import json; d=json.load(open('$CREDENTIALS_FILE')); print(d['client_id'])")
  TOKEN_ENDPOINT=$(python3 -c "import json; d=json.load(open('$CREDENTIALS_FILE')); print(d.get('token_endpoint','$SERVER_URL/oauth/token'))")
}

refresh_access_token() {
  echo "Refreshing access token..." >&2
  RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \\
    -H "Content-Type: application/x-www-form-urlencoded" \\
    -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN&client_id=$CLIENT_ID")

  NEW_ACCESS=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['access_token'])" 2>/dev/null)
  NEW_REFRESH=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('refresh_token','$REFRESH_TOKEN'))" 2>/dev/null)

  if [ -z "$NEW_ACCESS" ]; then
    echo "Error: Token refresh failed" >&2
    echo "$RESPONSE" >&2
    exit 1
  fi

  python3 -c "
import json
with open('$CREDENTIALS_FILE', 'r') as f:
    d = json.load(f)
d['access_token'] = '$NEW_ACCESS'
d['refresh_token'] = '$NEW_REFRESH'
with open('$CREDENTIALS_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"
  ACCESS_TOKEN="$NEW_ACCESS"
  REFRESH_TOKEN="$NEW_REFRESH"
  echo "Token refreshed successfully" >&2
}

mcp_call() {
  local tool_name="$1"
  local tool_args="$2"

  INIT_RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \\
    -H "Content-Type: application/json" \\
    -H "Authorization: Bearer $ACCESS_TOKEN" \\
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"${clientInfoName}","version":"1.0.0"}}}')

  if echo "$INIT_RESPONSE" | grep -q '"Unauthorized"' 2>/dev/null; then
    return 1
  fi

  curl -s -X POST "$MCP_ENDPOINT" \\
    -H "Content-Type: application/json" \\
    -H "Authorization: Bearer $ACCESS_TOKEN" \\
    -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null

  CALL_RESPONSE=$(curl -s -X POST "$MCP_ENDPOINT" \\
    -H "Content-Type: application/json" \\
    -H "Authorization: Bearer $ACCESS_TOKEN" \\
    -d "{\\"jsonrpc\\":\\"2.0\\",\\"id\\":2,\\"method\\":\\"tools/call\\",\\"params\\":{\\"name\\":\\"$tool_name\\",\\"arguments\\":$tool_args}}")

  echo "$CALL_RESPONSE"
}

if [ $# -lt 2 ]; then
  echo "Usage: $0 <tool_name> '<json_arguments>'" >&2
  echo "Example: $0 cookiy_help '{\\"topic\\":\\"overview\\"}'" >&2
  exit 1
fi

TOOL_NAME="$1"
TOOL_ARGS="$2"

read_credentials

RESULT=$(mcp_call "$TOOL_NAME" "$TOOL_ARGS")
if [ $? -ne 0 ] || echo "$RESULT" | grep -q '"Unauthorized"' 2>/dev/null; then
  if [ -n "$REFRESH_TOKEN" ]; then
    refresh_access_token
    RESULT=$(mcp_call "$TOOL_NAME" "$TOOL_ARGS")
  else
    echo "Error: Unauthorized and no refresh token available" >&2
    exit 1
  fi
fi

echo "$RESULT"
`;
}

export function generateMcpCallScriptPowerShell(
  serverUrl,
  mcpEndpoint,
  credentialsPath,
  { clientInfoName = 'headless-oauth' } = {},
) {
  return `# Cookiy MCP call script (PowerShell)
# Generated by cookiy-mcp CLI
# Usage: .\\mcp-call.ps1 <tool_name> '<json_arguments>'

$ErrorActionPreference = "Stop"

$CREDENTIALS_FILE = "${credentialsPath}"
$MCP_ENDPOINT = "${mcpEndpoint}"
$SERVER_URL = "${serverUrl}"

function Read-Credentials {
    if (-not (Test-Path $CREDENTIALS_FILE)) {
        Write-Error "credentials.json not found at $CREDENTIALS_FILE"
        exit 1
    }
    $script:creds = Get-Content $CREDENTIALS_FILE -Raw | ConvertFrom-Json
    $script:ACCESS_TOKEN = $creds.access_token
    $script:REFRESH_TOKEN = $creds.refresh_token
    $script:CLIENT_ID = $creds.client_id
    $script:TOKEN_ENDPOINT = if ($creds.token_endpoint) { $creds.token_endpoint } else { "$SERVER_URL/oauth/token" }
}

function Refresh-AccessToken {
    Write-Host "Refreshing access token..." -ForegroundColor Yellow
    $body = "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN&client_id=$CLIENT_ID"
    $response = Invoke-RestMethod -Uri $TOKEN_ENDPOINT -Method POST -ContentType "application/x-www-form-urlencoded" -Body $body

    if (-not $response.access_token) {
        Write-Error "Token refresh failed"
        exit 1
    }

    $script:ACCESS_TOKEN = $response.access_token
    if ($response.refresh_token) { $script:REFRESH_TOKEN = $response.refresh_token }

    $creds.access_token = $script:ACCESS_TOKEN
    $creds.refresh_token = $script:REFRESH_TOKEN
    $creds | ConvertTo-Json -Depth 10 | Set-Content $CREDENTIALS_FILE -Encoding UTF8
    Write-Host "Token refreshed successfully" -ForegroundColor Green
}

function Invoke-McpCall {
    param([string]$ToolName, [string]$ToolArgs)

    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $ACCESS_TOKEN"
    }

    $initBody = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"${clientInfoName}","version":"1.0.0"}}}'
    try {
        $initResponse = Invoke-RestMethod -Uri $MCP_ENDPOINT -Method POST -Headers $headers -Body $initBody
    } catch {
        if ($_.Exception.Response.StatusCode -eq 401) { return $null }
        throw
    }

    $notifBody = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    Invoke-RestMethod -Uri $MCP_ENDPOINT -Method POST -Headers $headers -Body $notifBody | Out-Null

    $callBody = @{
        jsonrpc = "2.0"
        id      = 2
        method  = "tools/call"
        params  = @{
            name      = $ToolName
            arguments = ($ToolArgs | ConvertFrom-Json)
        }
    } | ConvertTo-Json -Depth 10

    $callResponse = Invoke-RestMethod -Uri $MCP_ENDPOINT -Method POST -Headers $headers -Body $callBody
    return $callResponse
}

if ($args.Count -lt 2) {
    Write-Host "Usage: .\\mcp-call.ps1 <tool_name> '<json_arguments>'" -ForegroundColor Yellow
    Write-Host "Example: .\\mcp-call.ps1 cookiy_help '{""topic"":""overview""}'" -ForegroundColor Gray
    exit 1
}

$TOOL_NAME = $args[0]
$TOOL_ARGS = $args[1]

Read-Credentials

$result = Invoke-McpCall -ToolName $TOOL_NAME -ToolArgs $TOOL_ARGS
if ($null -eq $result) {
    if ($REFRESH_TOKEN) {
        Refresh-AccessToken
        $result = Invoke-McpCall -ToolName $TOOL_NAME -ToolArgs $TOOL_ARGS
    } else {
        Write-Error "Unauthorized and no refresh token available"
        exit 1
    }
}

$result | ConvertTo-Json -Depth 20
`;
}

export async function installHeadlessOauthClient(serverUrl, serverName, {
  configPath,
  clientLabel,
  registrationClientName,
  callScriptClientInfoName,
  extraNotes = [],
} = {}) {
  const endpoint = mcpUrl(serverUrl);
  const paths = resolveHeadlessWorkspacePaths(configPath, serverName);

  for (const name of LEGACY_SERVER_NAMES) {
    const legacyDir = join(configPath, name);
    if (existsSync(legacyDir)) {
      rmSync(legacyDir, { recursive: true, force: true });
    }
  }

  mkdirSync(paths.workspaceDir, { recursive: true });

  console.log();
  console.log(`  ${c.cyan(`${clientLabel} MCP Setup`)}`);
  console.log(
    `  This will register an OAuth client, authenticate in your browser,`,
  );
  console.log(
    `  and generate credentials + ${paths.scriptName} for ${clientLabel}.`,
  );
  console.log();

  let session = readJsonFile(paths.pendingSessionPath);
  if (isReusablePendingOAuthSession(session, serverUrl)) {
    console.log(
      `  ${c.yellow('Resume:')} reusing pending OAuth session from ${c.dim(paths.pendingSessionPath)}`,
    );
  } else {
    session = null;
    console.log(`  ${c.dim('[0/4]')} Fetching OAuth metadata...`);
    const metadata = await fetchOAuthMetadata(serverUrl);
    const authorizationEndpoint = metadata.authorization_endpoint;
    const tokenEndpoint = metadata.token_endpoint;
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
      authorizationEndpoint,
      clientId,
      redirectUri,
      codeChallenge,
      state,
    );
    console.log(`  ${c.green('OK')} PKCE ready`);

    session = buildPendingOAuthSession({
      clientLabel,
      serverUrl,
      endpoint,
      metadata,
      callbackPort,
      redirectUri,
      clientId,
      codeVerifier,
      codeChallenge,
      state,
      authUrl,
    });
    writeJsonFile(paths.pendingSessionPath, session);
    console.log(
      `  ${c.green('Saved')} ${c.dim(paths.pendingSessionPath)} ${c.dim('(resume-safe OAuth session)')}`,
    );
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

  const callbackResult = await waitForAuthCode(
    session.callback_port,
    session.state,
  );

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

  const credentials = {
    server_url: serverUrl,
    mcp_url: endpoint,
    token_endpoint: session.token_endpoint,
    client_id: session.client_id,
    access_token: tokenResponse.access_token,
    refresh_token: tokenResponse.refresh_token || '',
    token_type: tokenResponse.token_type || 'Bearer',
    created_at: new Date().toISOString(),
  };
  writeJsonFile(paths.credentialsPath, credentials);
  console.log(`  ${c.green('Saved')} ${c.dim(paths.credentialsPath)}`);

  const script = process.platform === 'win32'
    ? generateMcpCallScriptPowerShell(serverUrl, endpoint, paths.credentialsPath, {
      clientInfoName: callScriptClientInfoName,
    })
    : generateMcpCallScript(serverUrl, endpoint, paths.credentialsPath, {
      clientInfoName: callScriptClientInfoName,
    });
  writeFileSync(paths.scriptPath, script, 'utf8');
  if (process.platform !== 'win32') chmodSync(paths.scriptPath, 0o755);
  console.log(`  ${c.green('Saved')} ${c.dim(paths.scriptPath)}`);

  writeFileSync(paths.notesPath, generateInstallNotes({
    clientLabel,
    serverUrl,
    endpoint,
    credentialsPath: paths.credentialsPath,
    scriptPath: paths.scriptPath,
    pendingSessionPath: paths.pendingSessionPath,
    extraNotes,
  }), 'utf8');
  console.log(`  ${c.green('Saved')} ${c.dim(paths.notesPath)}`);

  rmSync(paths.pendingSessionPath, { force: true });
  console.log(`  ${c.green('Cleared')} ${c.dim(paths.pendingSessionPath)}`);

  console.log(`  ${c.dim('[5/5]')} Verifying Cookiy MCP connection...`);
  await verifyCookiyMcpConnection(endpoint, credentials.access_token, {
    clientInfoName: callScriptClientInfoName,
  });
  console.log(`  ${c.green('OK')} Cookiy MCP installed and verified successfully.`);
  console.log();

  return `${paths.scriptName} ready at ${paths.scriptPath}`;
}

export async function removeHeadlessOauthClient(serverName, { configPath } = {}) {
  const { workspaceDir } = resolveHeadlessWorkspacePaths(configPath, serverName);
  if (existsSync(workspaceDir)) {
    rmSync(workspaceDir, { recursive: true, force: true });
  }
}
