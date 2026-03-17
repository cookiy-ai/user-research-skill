import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import {
  installLocalSkill,
  removeLocalSkill,
  resolvePackagedSkillAssetsDir,
  resolveLocalSkillPath,
  supportsLocalSkillInstall,
} from '../../lib/skills/local-skill.mjs';

const testDir = dirname(fileURLToPath(import.meta.url));
const packageDir = join(testDir, '..', '..');

test('resolves local skill paths for supported clients', () => {
  assert.equal(resolveLocalSkillPath('codex', 'cookiy', '/tmp/home'), '/tmp/home/.agents/skills/cookiy');
  assert.equal(resolveLocalSkillPath('claudeCode', 'cookiy', '/tmp/home'), '/tmp/home/.claude/skills/cookiy');
  assert.equal(resolveLocalSkillPath('openclaw', 'cookiy', '/tmp/home'), '/tmp/home/.openclaw/skills/cookiy');
  assert.equal(resolveLocalSkillPath('cursor', 'cookiy', '/tmp/home'), null);
  assert.equal(supportsLocalSkillInstall('codex'), true);
  assert.equal(supportsLocalSkillInstall('cursor'), false);
});

test('resolves packaged skill assets from explicit env path', () => {
  process.env.COOKIY_SKILL_ASSETS_DIR = join(tmpdir(), 'cookiy-nonexistent-skill-assets');
  const resolved = resolvePackagedSkillAssetsDir({
    runtimePath: '/tmp/app/bin/cli.mjs',
    execPath: '/tmp/app/cookiy',
  });
  assert.equal(resolved, null);
  delete process.env.COOKIY_SKILL_ASSETS_DIR;
});

test('installs and removes packaged local skill assets', async () => {
  const homeDir = await mkdtemp(join(tmpdir(), 'cookiy-skill-home-'));
  const targetDir = await installLocalSkill('claudeCode', 'cookiy', {
    homeDir,
    skillAssetsDir: join(packageDir, 'skill-assets'),
  });

  const rootSkill = await readFile(join(targetDir, 'SKILL.md'), 'utf8');
  const nestedSkill = await readFile(join(targetDir, 'skills', 'cookiy', 'SKILL.md'), 'utf8');

  assert.match(rootSkill, /^---/m);
  assert.match(nestedSkill, /^---/m);

  await removeLocalSkill('claudeCode', 'cookiy', { homeDir });
  assert.equal(resolveLocalSkillPath('claudeCode', 'cookiy', homeDir), join(homeDir, '.claude', 'skills', 'cookiy'));
});
