export const DEFAULT_SERVER_URL = 'https://s-api.cookiy.ai';
export const SERVER_NAME = 'cookiy';
export const VERSION = '1.9.0';

// Legacy names from previous versions — removed during install to avoid duplicates
export const LEGACY_SERVER_NAMES = ['cookiy_mcp', 'cookiy-mcp', 'cookiy_v1', 'cookiy-v1'];

// Short aliases so users can type `npx cookiy-mcp dev` instead of full URLs
export const ENV_ALIASES = {
  prod: 'https://s-api.cookiy.ai',
  production: 'https://s-api.cookiy.ai',
  dev: 'https://dev-api.cookiy.ai',
  dev2: 'https://dev2-api.cookiy.ai',
  preview: 'https://preview-api.cookiy.ai',
  staging: 'https://staging-api.cookiy.ai',
  test: 'https://test-api.cookiy.ai',
};

/**
 * Auto-correct frontend URLs to API URLs.
 * e.g. dev.cookiy.ai → dev-api.cookiy.ai, app.cookiy.ai → s-api.cookiy.ai
 */
export function resolveApiUrl(serverUrl) {
  const url = new URL(serverUrl);
  const host = url.host.toLowerCase();

  // Already an API domain
  if (host.includes('-api.')) return serverUrl;

  const frontendToApi = {
    'app.cookiy.ai': 's-api.cookiy.ai',
    'cookiy.ai': 's-api.cookiy.ai',
    's.cookiy.ai': 's-api.cookiy.ai',
  };

  if (frontendToApi[host]) {
    url.host = frontendToApi[host];
    return url.toString();
  }

  // Pattern: dev.cookiy.ai → dev-api.cookiy.ai, preview.cookiy.ai → preview-api.cookiy.ai
  const match = host.match(/^([a-z0-9]+)\.cookiy\.ai$/);
  if (match) {
    url.host = `${match[1]}-api.cookiy.ai`;
    return url.toString();
  }

  return serverUrl;
}

export function resolveEnvironmentLabel(serverUrl) {
  const url = new URL(serverUrl);
  const host = url.host.toLowerCase();

  if (host === 's-api.cookiy.ai' || host === 'app.cookiy.ai' || host === 'cookiy.ai' || host === 's.cookiy.ai') return 'production';
  if (host.startsWith('dev') && host.endsWith('.cookiy.ai')) return 'development';
  if (host.startsWith('staging') && host.endsWith('.cookiy.ai')) return 'staging';
  if (host.startsWith('preview') && host.endsWith('.cookiy.ai')) return 'preview';
  if (host.startsWith('test') && host.endsWith('.cookiy.ai')) return 'test';
  if (host.includes('zyking.xyz')) return 'local';
  return 'custom';
}

export function mcpUrl(serverUrl) {
  return new URL('/mcp', serverUrl).toString();
}

export function sseUrl(serverUrl) {
  return new URL('/sse', serverUrl).toString();
}

export function wellKnownUrl(serverUrl) {
  return new URL('/.well-known/oauth-authorization-server', serverUrl).toString();
}
