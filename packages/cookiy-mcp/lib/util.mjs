import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync } from 'node:fs';
import { dirname } from 'node:path';
import readline from 'node:readline';

// --- Terminal colors (no dependencies) ---

const isColorSupported = process.stdout.isTTY && !process.env.NO_COLOR;

export const c = {
  bold: (s) => (isColorSupported ? `\x1b[1m${s}\x1b[22m` : s),
  dim: (s) => (isColorSupported ? `\x1b[2m${s}\x1b[22m` : s),
  green: (s) => (isColorSupported ? `\x1b[32m${s}\x1b[39m` : s),
  red: (s) => (isColorSupported ? `\x1b[31m${s}\x1b[39m` : s),
  yellow: (s) => (isColorSupported ? `\x1b[33m${s}\x1b[39m` : s),
  cyan: (s) => (isColorSupported ? `\x1b[36m${s}\x1b[39m` : s),
};

// --- JSON file helpers ---

export function readJsonFile(filePath) {
  try {
    const raw = readFileSync(filePath, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === 'ENOENT') return null;
    throw new Error(`Failed to parse ${filePath}: ${err.message}`);
  }
}

export function writeJsonFile(filePath, data) {
  mkdirSync(dirname(filePath), { recursive: true });
  // Backup existing file
  if (existsSync(filePath)) {
    try {
      copyFileSync(filePath, filePath + '.bak');
    } catch {
      // ignore backup failure
    }
  }
  writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// --- TOML file helpers (string-based, no parser dependency) ---

export function readTomlFile(filePath) {
  try {
    return readFileSync(filePath, 'utf8');
  } catch (err) {
    if (err.code === 'ENOENT') return '';
    throw new Error(`Failed to read ${filePath}: ${err.message}`);
  }
}

export function removeTomlSection(content, section) {
  // Remove [section] block up to the next [header] or EOF
  const escaped = section.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`^\\[${escaped}\\][^\\[]*`, 'gm');
  let result = content.replace(re, '');
  // Collapse 3+ consecutive blank lines into 2
  result = result.replace(/\n{3,}/g, '\n\n');
  return result;
}

export function upsertTomlMcpServer(content, serverName, url) {
  const section = `mcp_servers.${serverName}`;
  let cleaned = removeTomlSection(content, section);
  // Ensure content ends with a single newline before appending
  cleaned = cleaned.replace(/\s+$/, '') + '\n';
  cleaned += `\n[${section}]\nurl = "${url}"\n`;
  return cleaned;
}

export function writeTomlFile(filePath, content) {
  mkdirSync(dirname(filePath), { recursive: true });
  if (existsSync(filePath)) {
    try {
      copyFileSync(filePath, filePath + '.bak');
    } catch {
      // ignore backup failure
    }
  }
  writeFileSync(filePath, content, 'utf8');
}

// --- Interactive prompt ---

export function confirm(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (answer) => {
      rl.close();
      const normalized = answer.trim().toLowerCase();
      resolve(normalized === '' || normalized === 'y' || normalized === 'yes');
    });
  });
}

export function prompt(question) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

/**
 * Let the user pick items from a numbered list.
 * @param {Array<{label: string, detail: string}>} items
 * @param {string} promptText
 * @returns {Promise<number[]|null>} selected indices (0-based), or null if cancelled
 */
export async function selectFromList(items, promptText) {
  const answer = await prompt(promptText);

  // Enter = select all
  if (answer === '') return items.map((_, i) => i);

  // Cancel
  if (answer.toLowerCase() === 'n' || answer === '0') return null;

  const indices = new Set();
  for (const part of answer.split(',')) {
    const trimmed = part.trim();
    if (trimmed === '') continue;
    const rangeMatch = trimmed.match(/^(\d+)\s*-\s*(\d+)$/);
    if (rangeMatch) {
      const start = parseInt(rangeMatch[1], 10);
      const end = parseInt(rangeMatch[2], 10);
      for (let i = start; i <= end; i++) {
        if (i >= 1 && i <= items.length) indices.add(i - 1);
      }
    } else {
      const num = parseInt(trimmed, 10);
      if (!isNaN(num) && num >= 1 && num <= items.length) indices.add(num - 1);
    }
  }

  if (indices.size === 0) return null;
  return [...indices].sort((a, b) => a - b);
}
