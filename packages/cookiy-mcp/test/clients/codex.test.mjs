import test from 'node:test';
import assert from 'node:assert/strict';
import { isExpectedCodexOAuthTimeout } from '../../lib/clients/codex.mjs';

test('treats execFileSync timeout errors as deferred OAuth', () => {
  assert.equal(
    isExpectedCodexOAuthTimeout({
      code: 'ETIMEDOUT',
      signal: 'SIGTERM',
      message: 'spawnSync codex ETIMEDOUT',
    }),
    true,
  );

  assert.equal(
    isExpectedCodexOAuthTimeout({
      signal: 'SIGTERM',
      message: 'Command failed because it timed out after 30000ms',
    }),
    true,
  );

  assert.equal(
    isExpectedCodexOAuthTimeout({
      killed: true,
      message: 'legacy timeout shape',
    }),
    true,
  );

  assert.equal(
    isExpectedCodexOAuthTimeout({
      code: 'ENOENT',
      message: 'codex not found',
    }),
    false,
  );
});
