/**
 * HTTPS JSON-RPC to Cookiy hosted /mcp (same sequence as headless mcp-call scripts).
 * Uses global fetch (Node 18+).
 */

const DEFAULT_TIMEOUT_MS = 120_000;

export async function postJsonRpc(endpoint, payload, accessToken, opts = {}) {
  const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), timeoutMs);
  if (opts.signal) {
    opts.signal.addEventListener('abort', () => ac.abort(), { once: true });
  }

  let res;
  try {
    res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
      signal: ac.signal,
    });
  } catch (err) {
    clearTimeout(t);
    if (err.name === 'AbortError') {
      throw new Error(`MCP request timed out after ${timeoutMs}ms`);
    }
    throw new Error(`MCP request failed: ${err.message}`);
  }
  clearTimeout(t);

  const text = await res.text();
  if (!res.ok) {
    throw new Error(`MCP HTTP ${res.status}: ${text || res.statusText}`);
  }
  if (!text.trim()) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`MCP returned invalid JSON: ${text}`);
  }
}

let rpcId = 1;
function nextId() {
  return rpcId++;
}

export async function callCookiyTool(mcpEndpoint, accessToken, tool, opts = {}) {
  const clientInfoName = opts.clientInfoName ?? 'cookiy-cli';
  const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;

  const initResponse = await postJsonRpc(
    mcpEndpoint,
    {
      jsonrpc: '2.0',
      id: nextId(),
      method: 'initialize',
      params: {
        protocolVersion: '2025-03-26',
        capabilities: {},
        clientInfo: { name: clientInfoName, version: '1.0.0' },
      },
    },
    accessToken,
    { timeoutMs },
  );

  if (initResponse.error) {
    throw new Error(`MCP initialize failed: ${initResponse.error.message || 'unknown error'}`);
  }

  await postJsonRpc(
    mcpEndpoint,
    { jsonrpc: '2.0', method: 'notifications/initialized' },
    accessToken,
    { timeoutMs },
  );

  const toolResponse = await postJsonRpc(
    mcpEndpoint,
    {
      jsonrpc: '2.0',
      id: nextId(),
      method: 'tools/call',
      params: {
        name: tool.name,
        arguments: tool.arguments && typeof tool.arguments === 'object' ? tool.arguments : {},
      },
    },
    accessToken,
    { timeoutMs },
  );

  if (toolResponse.error) {
    const msg = toolResponse.error.message || JSON.stringify(toolResponse.error);
    const err = new Error(msg);
    err.rpcError = toolResponse.error;
    throw err;
  }

  return toolResponse.result;
}

export function isUnauthorizedError(err) {
  const m = err?.message || '';
  return /\b401\b/.test(m) || /Unauthorized/i.test(m);
}
