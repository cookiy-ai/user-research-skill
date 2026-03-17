import https from 'node:https';
import http from 'node:http';
import { wellKnownUrl } from './config.mjs';

export async function validateServer(serverUrl, { timeout = 10000 } = {}) {
  const endpoint = wellKnownUrl(serverUrl);
  const parsedUrl = new URL(endpoint);

  // Allow self-signed certs for local dev domains
  const isLocalDev = parsedUrl.hostname.includes('zyking.xyz') || parsedUrl.hostname === 'localhost';

  return new Promise((resolve, reject) => {
    const client = parsedUrl.protocol === 'https:' ? https : http;
    const options = {
      timeout,
      ...(isLocalDev && { rejectUnauthorized: false }),
    };

    const req = client.get(parsedUrl, options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error(`Server returned ${res.statusCode}. Is ${serverUrl} a valid Cookiy MCP server?`));
          return;
        }
        try {
          const metadata = JSON.parse(body);
          if (!metadata.authorization_endpoint || !metadata.token_endpoint) {
            reject(new Error('Server metadata missing required OAuth endpoints.'));
            return;
          }
          resolve(metadata);
        } catch {
          reject(new Error('Server returned invalid JSON at well-known endpoint.'));
        }
      });
    });

    req.on('error', (err) => reject(new Error(`Cannot reach ${serverUrl}: ${err.message}`)));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Connection to ${serverUrl} timed out.`));
    });
  });
}
