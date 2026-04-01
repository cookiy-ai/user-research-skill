import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import { callCookiyTool, postJsonRpc } from '../lib/mcp-call-http.mjs';

test('postJsonRpc returns parsed JSON body', async (t) => {
  const fn = mock.fn(async () => new Response(JSON.stringify({ ok: 1 }), { status: 200 }));
  t.mock.method(globalThis, 'fetch', fn);

  const out = await postJsonRpc('https://example.com/mcp', { x: 1 }, 'tok');
  assert.equal(out.ok, 1);
  assert.equal(fn.mock.calls.length, 1);
});

test('callCookiyTool runs initialize, notification, tools/call', async (t) => {
  const fn = mock.fn(async (_url, init) => {
    const body = JSON.parse(init.body);
    if (body.method === 'initialize') {
      return new Response(JSON.stringify({ jsonrpc: '2.0', id: body.id, result: {} }), { status: 200 });
    }
    if (body.method === 'notifications/initialized') {
      return new Response(JSON.stringify({}), { status: 200 });
    }
    if (body.method === 'tools/call') {
      return new Response(
        JSON.stringify({
          jsonrpc: '2.0',
          id: body.id,
          result: { structuredContent: { ok: true, tool: body.params.name } },
        }),
        { status: 200 },
      );
    }
    return new Response('bad', { status: 500 });
  });
  t.mock.method(globalThis, 'fetch', fn);

  const result = await callCookiyTool('https://example.com/mcp', 'tok', {
    name: 'cookiy_introduce',
    arguments: {},
  });

  assert.equal(result.structuredContent.tool, 'cookiy_introduce');
  assert.equal(fn.mock.calls.length, 3);
});
