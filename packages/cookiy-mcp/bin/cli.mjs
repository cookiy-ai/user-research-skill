#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { DEFAULT_SERVER_URL, SERVER_NAME, VERSION, ENV_ALIASES, resolveEnvironmentLabel, resolveApiUrl } from '../lib/config.mjs';
import { validateServer } from '../lib/validate.mjs';
import { detectClients } from '../lib/detect.mjs';
import { c, selectFromList } from '../lib/util.mjs';
import * as claudeCodeClient from '../lib/clients/claude-code.mjs';
import * as cursorClient from '../lib/clients/cursor.mjs';
import * as vscodeClient from '../lib/clients/vscode.mjs';
import * as codexClient from '../lib/clients/codex.mjs';
import * as windsurfClient from '../lib/clients/windsurf.mjs';
import * as clineClient from '../lib/clients/cline.mjs';
import * as openclawClient from '../lib/clients/openclaw.mjs';
import * as manusClient from '../lib/clients/manus.mjs';

const clientModules = {
  claudeCode: claudeCodeClient,
  cursor: cursorClient,
  vscode: vscodeClient,
  codex: codexClient,
  windsurf: windsurfClient,
  cline: clineClient,
  openclaw: openclawClient,
  manus: manusClient,
};

export async function main(argv = process.argv.slice(2)) {
  // --- Parse arguments ---

  let parsed;
  try {
    parsed = parseArgs({
      args: argv,
      allowPositionals: true,
      options: {
        client: { type: 'string' },
        name: { type: 'string', default: SERVER_NAME },
        scope: { type: 'string', default: 'user' },
        remove: { type: 'boolean', default: false },
        'dry-run': { type: 'boolean', default: false },
        yes: { type: 'boolean', short: 'y', default: false },
        help: { type: 'boolean', short: 'h', default: false },
        version: { type: 'boolean', short: 'v', default: false },
      },
    });
  } catch (err) {
    console.error(c.red(`Error: ${err.message}`));
    console.error('Run with --help for usage information.');
    process.exit(1);
  }

  const { values: opts, positionals } = parsed;

  // --- Help ---

  if (opts.help) {
    console.log(`
  ${c.bold('Cookiy MCP Setup')} v${VERSION}

  One-command setup for Cookiy MCP server in your AI coding clients.

  ${c.bold('Usage:')}
    npx cookiy-mcp [server-url] [options]

  ${c.bold('Arguments:')}
    server-url              MCP server base URL, or environment alias:
                            prod, dev, dev2, preview, staging, test
                            (default: prod → ${DEFAULT_SERVER_URL})

  ${c.bold('Options:')}
    --client <name>         Only configure a specific client
                            (claudeCode, cursor, vscode, codex, windsurf, cline, openclaw, manus)
    --name <server-name>    Override MCP server name (default: ${SERVER_NAME})
    --scope <scope>         Claude Code scope: user|project (default: user)
    --remove                Remove Cookiy MCP config from detected clients
    --dry-run               Show what would be done without writing
    -y, --yes               Skip confirmation prompt
    -h, --help              Show this help
    -v, --version           Show version

  ${c.bold('Examples:')}
    npx cookiy-mcp                                 # production (default)
    npx cookiy-mcp https://s-api.cookiy.ai         # explicit production URL also works
    npx cookiy-mcp --client cursor                 # only configure Cursor
    npx cookiy-mcp --client manus                  # headless OAuth bundle for Manus-like sandboxes
    npx cookiy-mcp --remove                        # remove from all clients
    npx cookiy-mcp --dry-run                       # preview changes
`);
    process.exit(0);
  }

  if (opts.version) {
    console.log(VERSION);
    process.exit(0);
  }

  // --- Resolve server URL ---

  const rawInput = positionals[0] || '';
  const aliasUrl = ENV_ALIASES[rawInput.toLowerCase()];
  const rawUrl = aliasUrl || rawInput || DEFAULT_SERVER_URL;

  try {
    new URL(rawUrl);
  } catch {
    console.error(c.red(`Error: Invalid URL or alias "${rawInput}"`));
    console.error(`  Available aliases: ${Object.keys(ENV_ALIASES).join(', ')}`);
    process.exit(1);
  }

  const serverUrl = resolveApiUrl(rawUrl);
  if (aliasUrl) {
    // User typed an alias like "dev"
  } else if (serverUrl !== rawUrl) {
    console.log();
    console.log(`  ${c.yellow('Note:')} ${rawUrl} looks like a frontend URL.`);
    console.log(`  ${c.yellow('  →')} Using API URL: ${c.cyan(serverUrl)}`);
  }

  const envLabel = resolveEnvironmentLabel(serverUrl);
  const isRemove = opts.remove;
  const isDryRun = opts['dry-run'];
  const serverName = opts.name;

  // --- Header ---

  console.log();
  console.log(`  ${c.bold('Cookiy MCP Setup')} v${VERSION}`);
  console.log();

  // --- Validate server (skip for remove and dry-run) ---

  if (!isRemove) {
    console.log(`  Server:   ${c.cyan(serverUrl)} (${envLabel})`);

    if (isDryRun) {
      console.log(`  Verified: ${c.yellow('skipped (dry-run)')}`);
    } else {
      try {
        await validateServer(serverUrl);
        console.log(`  Verified: ${c.green('OAuth discovery endpoint reachable')}`);
      } catch (err) {
        console.error(`  Verified: ${c.red('FAILED')}`);
        console.error(`  ${c.red(err.message)}`);
        console.error();
        console.error('  Please check the server URL and try again.');
        process.exit(1);
      }
    }
  } else {
    console.log(`  Mode:     ${c.yellow('Remove')} Cookiy MCP config`);
    console.log(`  Name:     ${serverName}`);
  }

  console.log();

  // --- Detect clients ---

  const allClients = detectClients();
  let targetClients;

  if (opts.client) {
    const key = opts.client;
    if (!allClients[key]) {
      console.error(c.red(`  Error: Unknown client "${key}"`));
      console.error(`  Available: ${Object.keys(allClients).join(', ')}`);
      process.exit(1);
    }
    const explicitClient = allClients[key];
    targetClients = {
      [key]: {
        ...explicitClient,
        detected: true,
        detail: explicitClient.detected
          ? explicitClient.detail
          : 'forced by --client',
      },
    };
  } else {
    targetClients = allClients;
  }

  // --- Display detection results & select ---

  console.log('  Detected AI clients:');

  const allDetected = [];
  for (const [key, client] of Object.entries(targetClients)) {
    if (client.detected) {
      allDetected.push([key, client]);
    }
  }

  if (allDetected.length === 0) {
    for (const [, client] of Object.entries(targetClients)) {
      console.log(`    ${c.dim('[ ]')} ${c.dim(client.name.padEnd(14))} ${c.dim('(not detected)')}`);
    }
    console.log();
    console.log(c.yellow('  No supported AI clients detected.'));
    console.log('  Supported: Claude Code, Cursor, VS Code, Codex, Windsurf, Cline, OpenClaw, Manus');
    console.log();
    process.exit(0);
  }

  // Show numbered list of detected clients
  for (let i = 0; i < allDetected.length; i++) {
    const [, client] = allDetected[i];
    console.log(`    ${c.bold(String(i + 1))}. ${client.name.padEnd(14)} ${c.dim(`(${client.detail})`)}`);
  }

  console.log();

  const action = isRemove ? 'Remove' : 'Configure';
  let detectedEntries;

  if (opts.yes || isDryRun || opts.client) {
    // --yes, --dry-run, or --client: skip selection, use all detected
    detectedEntries = allDetected;
  } else {
    const total = allDetected.length;
    const selected = await selectFromList(
      allDetected,
      `  Select clients to ${action.toLowerCase()} (1-${total}, Enter=all, n=cancel): `,
    );
    if (!selected) {
      console.log('  Aborted.');
      process.exit(0);
    }
    detectedEntries = selected.map((i) => allDetected[i]);
    console.log();
  }

  if (isDryRun) {
    console.log(c.yellow('  [dry-run] No changes will be made.'));
    console.log();
  }

  // --- Install/Remove for each client ---

  let failCount = 0;

  for (const [key, client] of detectedEntries) {
    const mod = clientModules[key];
    const label = client.name.padEnd(14);

    if (isDryRun) {
      if (isRemove) {
        console.log(`  ${label} ... ${c.yellow('would remove')} ${serverName}`);
      } else {
        console.log(`  ${label} ... ${c.yellow('would configure')} ${serverUrl}`);
      }
      continue;
    }

    try {
      if (isRemove) {
        await mod.remove(serverName, {
          scope: opts.scope,
          cliPath: client.cliPath,
          configPath: client.configPath,
        });
        console.log(`  ${label} ... ${c.green('removed')}`);
      } else {
        const result = await mod.install(serverUrl, serverName, {
          scope: opts.scope,
          cliPath: client.cliPath,
          configPath: client.configPath,
        });
        console.log(`  ${label} ... ${c.green('done')} ${c.dim(`(${result})`)}`);
      }
    } catch (err) {
      console.log(`  ${label} ... ${c.red('failed')} ${c.dim(err.message)}`);
      failCount++;
    }
  }

  console.log();

  // --- Summary ---

  if (failCount === 0) {
    if (isRemove) {
      console.log(c.green('  All done! Cookiy MCP config has been removed.'));
    } else if (isDryRun) {
      console.log('  Re-run without --dry-run to apply changes.');
    } else {
      const hasOnlyOauth = detectedEntries.every(([key]) => allClients[key]?.method === 'oauth');
      const hasAnyOauth = detectedEntries.some(([key]) => allClients[key]?.method === 'oauth');
      const hasClaudeCode = detectedEntries.some(([key]) => key === 'claudeCode');
      const hasCursorOrVscode = detectedEntries.some(([key]) => key === 'cursor' || key === 'vscode');
      const codexEntry = detectedEntries.find(([key]) => key === 'codex');
      const hasOpenClaw = detectedEntries.some(([key]) => key === 'openclaw');
      const hasManus = detectedEntries.some(([key]) => key === 'manus');
      const hasCodex = !!codexEntry;
      const codexViaCli = hasCodex && allClients.codex?.cliPath;
      if (hasOnlyOauth) {
        console.log(c.green('  All set! Headless OAuth helper files are ready to use.'));
      } else {
        console.log(c.green('  All set! Next steps to activate:'));
        console.log();
        if (hasClaudeCode) {
          console.log(`    ${c.bold('Claude Code')}  → type ${c.cyan('/mcp')} then select ${c.cyan(serverName)} to authenticate`);
        }
        if (hasCursorOrVscode) {
          console.log(`    ${c.bold('Cursor/VS Code')} → open the editor, it will prompt you to log in automatically`);
        }
        if (hasCodex && codexViaCli) {
          console.log(`    ${c.bold('Codex (CLI)')} → it will prompt you to log in via OAuth when used`);
        }
        if (hasCodex && !codexViaCli) {
          console.log(`    ${c.bold('Codex (App)')} → open the app, it will prompt you to log in automatically`);
        }
        if (hasOpenClaw) {
          console.log(`    ${c.bold('OpenClaw')}     → use the generated workspace bundle and mcp-call.sh directly`);
        }
        if (hasManus) {
          console.log(`    ${c.bold('Manus')}        → use the generated bundle; managed ~/.mcp/servers.json is intentionally untouched`);
        }
        if (hasAnyOauth && !hasOpenClaw && !hasManus) {
          console.log(`    ${c.bold('Headless OAuth')} → mcp-call.sh is ready to use`);
        }
      }
    }
  } else {
    console.log(c.yellow(`  Done with ${failCount} error(s). Check the messages above.`));
  }

  console.log();
  process.exit(failCount > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(c.red(`Error: ${err.message}`));
  process.exit(1);
});
