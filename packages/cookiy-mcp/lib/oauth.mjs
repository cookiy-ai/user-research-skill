import https from 'node:https';
import http from 'node:http';
import crypto from 'node:crypto';

// --- HTTP helpers ---

function httpRequest(url, { method = 'POST', body, headers = {} } = {}) {
  const parsedUrl = new URL(url);
  const isLocalDev = parsedUrl.hostname.includes('zyking.xyz') || parsedUrl.hostname === 'localhost';
  const client = parsedUrl.protocol === 'https:' ? https : http;

  const payload = typeof body === 'string' ? body : new URLSearchParams(body).toString();

  return new Promise((resolve, reject) => {
    const options = {
      method,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(payload),
        ...headers,
      },
      timeout: 15000,
      ...(isLocalDev && { rejectUnauthorized: false }),
    };

    const req = client.request(parsedUrl, options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 400) {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          return;
        }
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error(`Invalid JSON response: ${data}`));
        }
      });
    });

    req.on('error', (err) => reject(new Error(`Request failed: ${err.message}`)));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out'));
    });

    req.write(payload);
    req.end();
  });
}

function httpPostJson(url, body) {
  const parsedUrl = new URL(url);
  const isLocalDev = parsedUrl.hostname.includes('zyking.xyz') || parsedUrl.hostname === 'localhost';
  const client = parsedUrl.protocol === 'https:' ? https : http;

  const payload = JSON.stringify(body);

  return new Promise((resolve, reject) => {
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: 15000,
      ...(isLocalDev && { rejectUnauthorized: false }),
    };

    const req = client.request(parsedUrl, options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 400) {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          return;
        }
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error(`Invalid JSON response: ${data}`));
        }
      });
    });

    req.on('error', (err) => reject(new Error(`Request failed: ${err.message}`)));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out'));
    });

    req.write(payload);
    req.end();
  });
}

// --- PKCE helpers ---

function base64url(buffer) {
  return buffer.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

export function generatePKCE() {
  const verifier = base64url(crypto.randomBytes(32));
  const challenge = base64url(crypto.createHash('sha256').update(verifier).digest());
  return { codeVerifier: verifier, codeChallenge: challenge };
}

// --- OAuth metadata ---

export function fetchOAuthMetadata(serverUrl) {
  const endpoint = new URL('/.well-known/oauth-authorization-server', serverUrl).toString();
  const parsedUrl = new URL(endpoint);
  const isLocalDev = parsedUrl.hostname.includes('zyking.xyz') || parsedUrl.hostname === 'localhost';
  const client = parsedUrl.protocol === 'https:' ? https : http;

  return new Promise((resolve, reject) => {
    const req = client.get(parsedUrl, {
      timeout: 10000,
      ...(isLocalDev && { rejectUnauthorized: false }),
    }, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error(`OAuth metadata returned HTTP ${res.statusCode}`));
          return;
        }
        try {
          const metadata = JSON.parse(body);
          if (!metadata.authorization_endpoint || !metadata.token_endpoint) {
            reject(new Error('OAuth metadata missing required endpoints'));
            return;
          }
          resolve(metadata);
        } catch {
          reject(new Error('OAuth metadata returned invalid JSON'));
        }
      });
    });
    req.on('error', (err) => reject(new Error(`Cannot fetch OAuth metadata: ${err.message}`)));
    req.on('timeout', () => { req.destroy(); reject(new Error('OAuth metadata request timed out')); });
  });
}

// --- OAuth flow functions ---

export async function registerClient(
  registrationEndpoint,
  redirectUri,
  clientName = 'Cookiy MCP CLI (OpenClaw)',
) {
  const result = await httpPostJson(registrationEndpoint, {
    client_name: clientName,
    redirect_uris: [redirectUri],
    grant_types: ['authorization_code', 'refresh_token'],
    response_types: ['code'],
    token_endpoint_auth_method: 'none',
  });

  if (!result.client_id) {
    throw new Error('Registration failed: no client_id returned');
  }

  return result;
}

export function buildAuthUrl(authorizationEndpoint, clientId, redirectUri, codeChallenge, state) {
  const url = new URL(authorizationEndpoint);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('code_challenge', codeChallenge);
  url.searchParams.set('code_challenge_method', 'S256');
  url.searchParams.set('state', state);
  return url.toString();
}

export async function exchangeCode(tokenEndpoint, code, clientId, redirectUri, codeVerifier) {
  return httpRequest(tokenEndpoint, {
    body: {
      grant_type: 'authorization_code',
      code,
      client_id: clientId,
      redirect_uri: redirectUri,
      code_verifier: codeVerifier,
    },
  });
}
