import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveMcpEndpoint } from '../lib/cookiy-credentials.mjs';

test('resolveMcpEndpoint prefers COOKIY_MCP_URL over creds and derived URL', () => {
  const prev = process.env.COOKIY_MCP_URL;
  process.env.COOKIY_MCP_URL = 'https://custom.example/mcp';
  try {
    const u = resolveMcpEndpoint(
      { mcp_url: 'https://wrong.example/mcp', server_url: 'https://s-api.cookiy.ai' },
      'https://s-api.cookiy.ai',
    );
    assert.equal(u, 'https://custom.example/mcp');
  } finally {
    if (prev === undefined) delete process.env.COOKIY_MCP_URL;
    else process.env.COOKIY_MCP_URL = prev;
  }
});

test('resolveMcpEndpoint uses creds.mcp_url when env unset', () => {
  const prev = process.env.COOKIY_MCP_URL;
  delete process.env.COOKIY_MCP_URL;
  try {
    const u = resolveMcpEndpoint(
      { mcp_url: 'https://file.example/mcp' },
      'https://s-api.cookiy.ai',
    );
    assert.equal(u, 'https://file.example/mcp');
  } finally {
    if (prev !== undefined) process.env.COOKIY_MCP_URL = prev;
  }
});
