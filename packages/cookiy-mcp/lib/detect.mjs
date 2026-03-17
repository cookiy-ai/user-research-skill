import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir, platform } from 'node:os';
import { execFileSync } from 'node:child_process';

function which(cmd) {
  try {
    const command = platform() === 'win32' ? 'where' : 'which';
    return execFileSync(command, [cmd], { encoding: 'utf8', timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] })
      .trim()
      .split('\n')[0];
  } catch {
    return null;
  }
}

export function detectClients() {
  const home = homedir();
  const isWindows = platform() === 'win32';
  const isMac = platform() === 'darwin';

  const clients = {};

  // Claude Code
  const claudePath = which('claude');
  clients.claudeCode = {
    key: 'claudeCode',
    name: 'Claude Code',
    detected: !!claudePath,
    cliPath: claudePath,
    method: 'cli',
    detail: claudePath ? `cli: ${claudePath}` : 'not detected',
  };

  // Cursor
  const cursorConfigPath = join(home, '.cursor', 'mcp.json');
  const cursorDetected = existsSync(join(home, '.cursor')) || !!which('cursor');
  clients.cursor = {
    key: 'cursor',
    name: 'Cursor',
    detected: cursorDetected,
    configPath: cursorConfigPath,
    method: 'json',
    jsonFormat: 'mcpServers',
    detail: cursorDetected ? cursorConfigPath : 'not detected',
  };

  // VS Code (Copilot)
  const codePath = which('code');
  let vscodeConfigPath;
  if (isMac) {
    vscodeConfigPath = join(home, 'Library', 'Application Support', 'Code', 'User', 'mcp.json');
  } else if (isWindows) {
    vscodeConfigPath = join(process.env.APPDATA || join(home, 'AppData', 'Roaming'), 'Code', 'User', 'mcp.json');
  } else {
    vscodeConfigPath = join(home, '.config', 'Code', 'User', 'mcp.json');
  }
  clients.vscode = {
    key: 'vscode',
    name: 'VS Code',
    detected: !!codePath,
    configPath: vscodeConfigPath,
    method: 'json',
    jsonFormat: 'servers',
    detail: codePath ? vscodeConfigPath : 'not detected',
  };

  // Codex (CLI or App)
  const codexPath = which('codex');
  const codexConfigDir = join(home, '.codex');
  const codexConfigPath = join(codexConfigDir, 'config.toml');
  const codexAppDetected = existsSync(codexConfigDir)
    || (isMac && existsSync('/Applications/Codex.app'));
  const codexDetected = !!codexPath || codexAppDetected;
  const codexMethod = codexPath ? 'cli' : 'toml';
  clients.codex = {
    key: 'codex',
    name: 'Codex',
    detected: codexDetected,
    cliPath: codexPath || null,
    configPath: codexConfigPath,
    method: codexMethod,
    detail: codexPath
      ? `cli: ${codexPath}`
      : codexAppDetected
        ? `app: ${codexConfigPath}`
        : 'not detected',
  };

  // Windsurf
  const windsurfDir = join(home, '.windsurf');
  const codeiumDir = join(home, '.codeium', 'windsurf');
  const windsurfDetected = existsSync(windsurfDir) || existsSync(codeiumDir) || !!which('windsurf');
  const windsurfConfigPath = existsSync(codeiumDir)
    ? join(codeiumDir, 'mcp_config.json')
    : join(windsurfDir, 'mcp.json');
  clients.windsurf = {
    key: 'windsurf',
    name: 'Windsurf',
    detected: windsurfDetected,
    configPath: windsurfConfigPath,
    method: 'json',
    jsonFormat: 'mcpServers',
    detail: windsurfDetected ? windsurfConfigPath : 'not detected',
  };

  // Cline
  const clineDir = join(home, '.cline');
  const clineDetected = existsSync(clineDir);
  clients.cline = {
    key: 'cline',
    name: 'Cline',
    detected: clineDetected,
    configPath: join(clineDir, 'mcp_settings.json'),
    method: 'json',
    jsonFormat: 'mcpServers',
    detail: clineDetected ? join(clineDir, 'mcp_settings.json') : 'not detected',
  };

  // OpenClaw
  const openclawDir = join(home, '.openclaw');
  const openclawDetected = existsSync(openclawDir);
  const openclawWorkspace = join(openclawDir, 'workspace');
  clients.openclaw = {
    key: 'openclaw',
    name: 'OpenClaw',
    detected: openclawDetected,
    configPath: openclawWorkspace,
    method: 'oauth',
    detail: openclawDetected ? openclawWorkspace : 'not detected',
  };

  // Manus
  const manusDir = join(home, '.mcp');
  const manusCliPath = which('manus-mcp-cli');
  const manusDetected = existsSync(manusDir) || !!manusCliPath || !!process.env.MANUS_SANDBOX;
  clients.manus = {
    key: 'manus',
    name: 'Manus',
    detected: manusDetected,
    cliPath: manusCliPath || null,
    configPath: manusDir,
    method: 'oauth',
    detail: manusCliPath
      ? `cli: ${manusCliPath}`
      : manusDetected
        ? manusDir
        : 'not detected',
  };

  return clients;
}
