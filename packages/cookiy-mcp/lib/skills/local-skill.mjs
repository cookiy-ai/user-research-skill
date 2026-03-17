import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const packageDir = dirname(fileURLToPath(new URL('../../package.json', import.meta.url)));
const skillAssetsDir = join(packageDir, 'skill-assets');

const LOCAL_SKILL_CLIENTS = new Set(['codex', 'claudeCode', 'openclaw']);

export function supportsLocalSkillInstall(clientKey) {
  return LOCAL_SKILL_CLIENTS.has(clientKey);
}

export function resolveLocalSkillPath(clientKey, serverName, homeDir = homedir()) {
  switch (clientKey) {
    case 'codex':
      return join(homeDir, '.agents', 'skills', serverName);
    case 'claudeCode':
      return join(homeDir, '.claude', 'skills', serverName);
    case 'openclaw':
      return join(homeDir, '.openclaw', 'skills', serverName);
    default:
      return null;
  }
}

export function getLocalSkillLabel(clientKey) {
  switch (clientKey) {
    case 'codex':
      return 'local skill';
    case 'claudeCode':
      return 'local Claude skill';
    case 'openclaw':
      return 'local OpenClaw skill';
    default:
      return 'local skill';
  }
}

export async function installLocalSkill(clientKey, serverName, { homeDir } = {}) {
  const targetDir = resolveLocalSkillPath(clientKey, serverName, homeDir);
  if (!targetDir) return null;

  if (!existsSync(skillAssetsDir)) {
    throw new Error(`Missing packaged skill assets: ${skillAssetsDir}`);
  }

  rmSync(targetDir, { recursive: true, force: true });
  mkdirSync(dirname(targetDir), { recursive: true });
  cpSync(skillAssetsDir, targetDir, { recursive: true });
  return targetDir;
}

export async function removeLocalSkill(clientKey, serverName, { homeDir } = {}) {
  const targetDir = resolveLocalSkillPath(clientKey, serverName, homeDir);
  if (!targetDir) return null;

  rmSync(targetDir, { recursive: true, force: true });
  return targetDir;
}
