import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { SERVER_NAME, VERSION } from '../lib/config.mjs';

const packageDir = dirname(fileURLToPath(new URL('../package.json', import.meta.url)));

test('package metadata stays aligned with CLI config', async () => {
  const packageJson = JSON.parse(
    await readFile(join(packageDir, 'package.json'), 'utf8'),
  );

  assert.equal(packageJson.version, VERSION);
  assert.equal(packageJson.name, 'cookiy-mcp');
  assert.equal(packageJson.bin['cookiy-mcp'], 'bin/cli.mjs');
  assert.equal(packageJson.scripts['build:bundle'], 'node ./scripts/build-bundle.mjs');
  assert.equal(packageJson.scripts['build:macos'], 'node ./scripts/build-macos-binary.mjs');
  assert.equal(packageJson.scripts['build:brew-formula'], 'node ./scripts/generate-homebrew-formula.mjs');
  assert.equal(SERVER_NAME, 'cookiy');
});
