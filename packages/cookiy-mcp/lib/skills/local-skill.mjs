import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';

const LOCAL_SKILL_CLIENTS = new Set(['codex', 'claudeCode', 'openclaw']);

export function resolvePackagedSkillAssetsDir({ runtimePath = process.argv[1], execPath = process.execPath } = {}) {
  const candidates = [];
  const explicit = process.env.COOKIY_SKILL_ASSETS_DIR;
  if (explicit) candidates.push(explicit);

  if (runtimePath) {
    const runtimeDir = dirname(resolve(runtimePath));
    candidates.push(join(dirname(runtimeDir), 'skill-assets'));
    candidates.push(join(runtimeDir, 'skill-assets'));
  }

  if (execPath) {
    const execDir = dirname(resolve(execPath));
    candidates.push(join(execDir, 'skill-assets'));
  }

  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }

  return null;
}

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

export async function installLocalSkill(clientKey, serverName, { homeDir, skillAssetsDir: explicitSkillAssetsDir } = {}) {
  const targetDir = resolveLocalSkillPath(clientKey, serverName, homeDir);
  if (!targetDir) return null;

  const skillAssetsDir = explicitSkillAssetsDir || resolvePackagedSkillAssetsDir();

  if (!skillAssetsDir || !existsSync(skillAssetsDir)) {
    throw new Error('Missing packaged skill assets for local skill bootstrap.');
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
