#!/usr/bin/env node
/**
 * Cookiy CLI — thin wrapper over hosted JSON-RPC (same tools as cookiy-mcp server).
 */
import {
  VERSION,
  DEFAULT_SERVER_URL,
  ENV_ALIASES,
  resolveApiUrl,
  mcpUrl,
} from '../lib/config.mjs';

import { callCookiyTool, isUnauthorizedError } from '../lib/mcp-call-http.mjs';
import {
  defaultCredentialsPath,
  loadCredentialsFile,
  refreshCredentialsFile,
  resolveMcpEndpoint,
  resolveServerBaseUrl,
} from '../lib/cookiy-credentials.mjs';
import { readJsonFile } from '../lib/util.mjs';
import { runCookiyCliOAuthLogin } from '../lib/cookiy-cli-oauth.mjs';

function usage() {
  return `Cookiy CLI v${VERSION}

Usage:
  cookiy [--server-url <url>] [--credentials <path>] <command> ...

Global options:
  --server-url     Override Cookiy API base URL (default: from credentials or production)
  --mcp-url        Full JSON-RPC URL (overrides COOKIY_MCP_URL and credentials mcp_url for this process)
  --credentials    Path to credentials.json (default: ~/.mcp/cookiy/credentials.json or \$COOKIY_CREDENTIALS)

Environment:
  COOKIY_CREDENTIALS   Path to credentials.json
  COOKIY_SERVER_URL    API base when not in file
  COOKIY_MCP_URL       Full MCP URL (e.g. https://s-api.cookiy.ai/mcp)

Commands:
  login [env|url]    Browser OAuth; writes tokens to the credentials path above (stable; same file for all cookiy commands)
  doctor                      Connectivity check (introduce)
  help <topic>                 Workflow help (--topic for natural form also accepted as first arg)
  study list|create|get|progress|activity|show|guide ...
  interview list|playback|simulate ...
  recruit start|status
  report status|share-link
  quant list|create|detail|patch|report|results|stats
  billing balance|checkout
  tool call <operation>        Escape hatch: --json '<arguments-object>'

Authenticate: \`cookiy login\` (recommended), or \`npx cookiy-mcp\` for IDE + skill install.

Examples:
  cookiy login
  cookiy login dev
  cookiy doctor
  cookiy study list --limit 10
  cookiy study create --query "..." --language zh
  cookiy tool call cookiy_study_get --json '{"study_id":"..."}'
`;
}

function die(msg, code = 1) {
  console.error(msg);
  process.exit(code);
}

/** Pull global flags from front of argv */
function extractGlobalOpts(argv) {
  const rest = [];
  let serverUrl = null;
  let credentialsPath = null;
  let mcpUrl = null;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--server-url' && argv[i + 1]) {
      serverUrl = argv[++i];
      continue;
    }
    if (a === '--mcp-url' && argv[i + 1]) {
      mcpUrl = argv[++i];
      continue;
    }
    if (a === '--credentials' && argv[i + 1]) {
      credentialsPath = argv[++i];
      continue;
    }
    rest.push(a);
  }
  return { rest, serverUrl, credentialsPath, mcpUrl };
}

/**
 * Parse `--key value` and `--flag` into { _: positionals, ...keys with dash→underscore }
 */
function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        out[key.replace(/-/g, '_')] = true;
      } else {
        out[key.replace(/-/g, '_')] = next;
        i++;
      }
    } else {
      out._.push(a);
    }
  }
  return out;
}

function boolish(v) {
  if (v === true || v === 'true' || v === '1') return true;
  if (v === false || v === 'false' || v === '0') return false;
  return Boolean(v);
}

function pickSnake(args, keys) {
  const o = {};
  for (const k of keys) {
    if (args[k] !== undefined && args[k] !== false) {
      let v = args[k];
      if (k === 'limit' || k === 'amount_cents') v = Number(v);
      if (k === 'include_debug') v = boolish(v);
      o[k] = v;
    }
  }
  return o;
}

function renderResult(result) {
  if (result?.structuredContent !== undefined) {
    console.log(JSON.stringify(result.structuredContent, null, 2));
    return;
  }
  console.log(JSON.stringify(result, null, 2));
}

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function pollActivity(ctx, studyId, { intervalMs = 2000, maxRounds = 45 } = {}) {
  let prev = null;
  for (let i = 0; i < maxRounds; i++) {
    const r = await ctx.invoke('cookiy_activity_get', { study_id: studyId });
    renderResult(r);
    const sig = JSON.stringify(r?.structuredContent ?? r);
    if (i > 2 && prev === sig) return;
    if (/complete|ready|failed|error|succeeded/i.test(sig) && i > 1) return;
    prev = sig;
    await sleep(intervalMs);
  }
}

async function pollSimStatus(ctx, studyId, jobId, { intervalMs = 2000, maxRounds = 45 } = {}) {
  let prev = null;
  for (let i = 0; i < maxRounds; i++) {
    const r = await ctx.invoke('cookiy_simulated_interview_status', {
      study_id: studyId,
      job_id: jobId,
    });
    renderResult(r);
    const sig = JSON.stringify(r?.structuredContent ?? r);
    if (i > 2 && prev === sig) return;
    if (/complete|ready|failed|error|succeeded|done/i.test(sig) && i > 1) return;
    prev = sig;
    await sleep(intervalMs);
  }
}

function createContext(credentialsPath, serverUrlOverride, mcpUrlOverride) {
  let creds = loadCredentialsFile(credentialsPath);
  if (serverUrlOverride) {
    creds = { ...creds, server_url: serverUrlOverride };
  }
  if (mcpUrlOverride) {
    creds = { ...creds, mcp_url: mcpUrlOverride };
  }
  const serverBase = resolveServerBaseUrl(creds);
  const mcpEndpoint = resolveMcpEndpoint(creds, serverBase);

  async function invoke(toolName, args) {
    try {
      return await callCookiyTool(mcpEndpoint, creds.access_token, {
        name: toolName,
        arguments: args,
      }, { clientInfoName: 'cookiy-cli' });
    } catch (err) {
      if (isUnauthorizedError(err) && creds.refresh_token) {
        creds = await refreshCredentialsFile(credentialsPath, creds);
        return callCookiyTool(mcpEndpoint, creds.access_token, {
          name: toolName,
          arguments: args,
        }, { clientInfoName: 'cookiy-cli' });
      }
      throw err;
    }
  }

  return { invoke, mcpEndpoint, credentialsPath, serverBase };
}

function extractStudyId(createResult) {
  const sc = createResult?.structuredContent ?? createResult;
  const data = sc?.data ?? sc;
  return (
    data?.study_id
    || data?.studyId
    || data?.study?.id
    || data?.id
    || null
  );
}

function extractJobId(genResult) {
  const sc = genResult?.structuredContent ?? genResult;
  const data = sc?.data ?? sc;
  return data?.job_id || data?.jobId || null;
}

async function main(argv) {
  if (!argv.length || argv[0] === '-h' || argv[0] === '--help') {
    console.log(usage());
    process.exit(0);
  }
  if (argv[0] === '-v' || argv[0] === '--version') {
    console.log(VERSION);
    process.exit(0);
  }

  const { rest, serverUrl, credentialsPath: credOpt, mcpUrl: gMcp } = extractGlobalOpts(argv);
  const credentialsPath = credOpt || defaultCredentialsPath();
  const [cmd, ...tail] = rest;
  if (!cmd) die('Missing command. Run cookiy --help');

  if (cmd === 'login') {
    const pos = tail.filter((a) => !a.startsWith('--'));
    const aliasOrUrl = pos[0];
    const rawFromPos = aliasOrUrl
      ? (ENV_ALIASES[aliasOrUrl.toLowerCase()] || aliasOrUrl)
      : '';
    const rawServer =
      serverUrl
      || rawFromPos
      || process.env.COOKIY_SERVER_URL
      || readJsonFile(credentialsPath)?.server_url
      || DEFAULT_SERVER_URL;
    const resolvedServer = resolveApiUrl(rawServer);
    let mcpEp = process.env.COOKIY_MCP_URL || gMcp;
    if (!mcpEp) {
      const prev = readJsonFile(credentialsPath);
      mcpEp = prev?.mcp_url || mcpUrl(resolvedServer);
    }
    try {
      await runCookiyCliOAuthLogin({
        serverUrl: resolvedServer,
        credentialsPath,
        mcpEndpoint: mcpEp,
      });
    } catch (err) {
      die(err?.message || String(err), 1);
    }
    return;
  }

  const ctx = createContext(credentialsPath, serverUrl, gMcp);

  try {
    if (cmd === 'doctor') {
      const r = await ctx.invoke('cookiy_introduce', {});
      renderResult(r);
      return;
    }

    if (cmd === 'help') {
      const a = parseArgs(tail);
      const topic = a._.join(' ') || a.topic;
      if (!topic) die('Usage: cookiy help <topic>');
      const r = await ctx.invoke('cookiy_help', { topic });
      renderResult(r);
      return;
    }

    if (cmd === 'tool') {
      const [sub, op, ...rtail] = tail;
      if (sub !== 'call' || !op) die('Usage: cookiy tool call <operation> --json \'{...}\'');
      const a = parseArgs(rtail);
      let argsObj = {};
      if (a.json) {
        try {
          argsObj = JSON.parse(a.json);
        } catch (e) {
          die(`Invalid --json: ${e.message}`);
        }
      }
      const r = await ctx.invoke(op, argsObj);
      renderResult(r);
      return;
    }

    if (cmd === 'study') {
      const [sub, ...stail] = tail;
      if (sub === 'list') {
        const a = parseArgs(stail);
        const r = await ctx.invoke('cookiy_study_list', pickSnake(a, ['query', 'status', 'limit', 'cursor']));
        renderResult(r);
        return;
      }
      if (sub === 'create') {
        const a = parseArgs(stail);
        const wait = a.wait === true;
        const body = pickSnake(a, ['query', 'language', 'thinking', 'attachments']);
        if (!body.query || !body.language) die('study create requires --query and --language');
        const r = await ctx.invoke('cookiy_study_create', body);
        renderResult(r);
        if (wait) {
          const sid = extractStudyId(r);
          if (!sid) die('Could not find study_id in create response for --wait', 2);
          await pollActivity(ctx, sid);
        }
        return;
      }
      if (sub === 'get') {
        const a = parseArgs(stail);
        const body = pickSnake(a, ['study_id']);
        if (!body.study_id) die('study get requires --study-id');
        const r = await ctx.invoke('cookiy_study_get', body);
        renderResult(r);
        return;
      }
      if (sub === 'progress' || sub === 'activity') {
        const a = parseArgs(stail);
        const body = pickSnake(a, ['study_id', 'job_id', 'include_debug']);
        if (!body.study_id) die('study progress requires --study-id');
        const r = await ctx.invoke('cookiy_activity_get', body);
        renderResult(r);
        return;
      }
      if (sub === 'show') {
        const a = parseArgs(stail);
        const part = a.part;
        const studyId = a.study_id;
        if (!studyId) die('study show requires --study-id');
        if (!part || part === 'both' || part === 'all') {
          renderResult(await ctx.invoke('cookiy_study_get', { study_id: studyId }));
          renderResult(await ctx.invoke('cookiy_activity_get', pickSnake(a, ['study_id', 'job_id', 'include_debug'])));
          return;
        }
        if (part === 'record') {
          renderResult(await ctx.invoke('cookiy_study_get', { study_id: studyId }));
          return;
        }
        if (part === 'progress') {
          renderResult(await ctx.invoke('cookiy_activity_get', pickSnake(a, ['study_id', 'job_id', 'include_debug'])));
          return;
        }
        die('study show: --part record|progress|both');
      }
      if (sub === 'guide') {
        const [gcmd, ...gtail] = stail;
        const a = parseArgs(gtail);
        if (gcmd === 'status') {
          if (!a.study_id) die('study guide status requires --study-id');
          renderResult(await ctx.invoke('cookiy_guide_status', { study_id: a.study_id }));
          return;
        }
        if (gcmd === 'get') {
          if (!a.study_id) die('study guide get requires --study-id');
          renderResult(await ctx.invoke('cookiy_guide_get', { study_id: a.study_id }));
          return;
        }
        if (gcmd === 'impact') {
          if (!a.study_id || !a.json) die('study guide impact requires --study-id and --json patch object');
          const patch = JSON.parse(a.json);
          renderResult(await ctx.invoke('cookiy_guide_impact', { study_id: a.study_id, patch }));
          return;
        }
        if (gcmd === 'patch') {
          const body = pickSnake(a, ['study_id', 'base_revision', 'idempotency_key', 'change_message', 'recruit_reconfigure_confirmed']);
          if (!body.study_id || !body.base_revision || !body.idempotency_key || !a.json) {
            die('study guide patch requires --study-id --base-revision --idempotency-key --json');
          }
          body.patch = JSON.parse(a.json);
          renderResult(await ctx.invoke('cookiy_guide_patch', body));
          return;
        }
        if (gcmd === 'upload') {
          const body = pickSnake(a, ['study_id', 'image_data', 'image_url', 'content_type']);
          if (!body.content_type) die('study guide upload requires --content-type');
          if (!body.image_data && !body.image_url) die('study guide upload requires --image-data or --image-url');
          renderResult(await ctx.invoke('cookiy_media_upload', body));
          return;
        }
        die('Unknown: study guide ' + (gcmd || ''));
      }
      die('Unknown study subcommand: ' + (sub || ''));
    }

    if (cmd === 'interview') {
      const [sub, ...itail] = tail;
      if (sub === 'list') {
        const a = parseArgs(itail);
        if (!a.study_id) die('interview list requires --study-id');
        renderResult(await ctx.invoke('cookiy_interview_list', pickSnake(a, ['study_id', 'include_simulation', 'cursor'])));
        return;
      }
      if (sub === 'playback') {
        const a = parseArgs(itail);
        if (!a.study_id || !a.interview_id) die('interview playback requires --study-id --interview-id');
        renderResult(await ctx.invoke('cookiy_interview_playback_get', pickSnake(a, ['study_id', 'interview_id'])));
        return;
      }
      if (sub === 'simulate') {
        const [ssub, ...srest] = itail;
        if (ssub === 'start') {
          const a = parseArgs(srest);
          const wait = a.wait === true;
          const body = { ...pickSnake(a, ['study_id', 'auto_generate_personas', 'persona_count', 'interviewee_persona']) };
          if (a.json) Object.assign(body, JSON.parse(a.json));
          if (!body.study_id) die('interview simulate start requires --study-id');
          const r = await ctx.invoke('cookiy_simulated_interview_generate', body);
          renderResult(r);
          if (wait) {
            const jobId = extractJobId(r);
            if (!jobId) die('Could not find job_id for --wait', 2);
            await pollSimStatus(ctx, body.study_id, jobId);
          }
          return;
        }
        if (ssub === 'status') {
          const a = parseArgs(srest);
          if (!a.study_id || !a.job_id) die('interview simulate status requires --study-id --job-id');
          renderResult(await ctx.invoke('cookiy_simulated_interview_status', pickSnake(a, ['study_id', 'job_id'])));
          return;
        }
        die('interview simulate start|status');
      }
      die('Unknown interview subcommand');
    }

    if (cmd === 'recruit') {
      const [sub, ...rtail] = tail;
      const a = parseArgs(rtail);
      if (sub === 'start') {
        const body = { ...pickSnake(a, ['study_id', 'confirmation_token', 'plain_text', 'target_participants', 'execution_duration', 'max_price_per_interview', 'channel_name', 'auto_launch', 'force_reconfigure', 'recruit_mode', 'survey_public_url']) };
        if (a.json) Object.assign(body, JSON.parse(a.json));
        if (!body.study_id) die('recruit start requires --study-id');
        const r = await ctx.invoke('cookiy_recruit_create', body);
        renderResult(r);
        return;
      }
      if (sub === 'status') {
        if (!a.study_id) die('recruit status requires --study-id');
        renderResult(await ctx.invoke('cookiy_recruit_status', { study_id: a.study_id }));
        return;
      }
      die('recruit start|status');
    }

    if (cmd === 'report') {
      const [sub, ...rtail] = tail;
      const a = parseArgs(rtail);
      if (sub === 'status') {
        if (!a.study_id) die('report status requires --study-id');
        renderResult(await ctx.invoke('cookiy_report_status', { study_id: a.study_id }));
        return;
      }
      if (sub === 'share-link') {
        if (!a.study_id) die('report share-link requires --study-id');
        renderResult(await ctx.invoke('cookiy_report_share_link_get', { study_id: a.study_id }));
        return;
      }
      die('report status|share-link');
    }

    if (cmd === 'quant') {
      const [sub, ...qtail] = tail;
      const a = parseArgs(qtail);
      const map = {
        list: 'cookiy_quant_survey_list',
        create: 'cookiy_quant_survey_create',
        detail: 'cookiy_quant_survey_detail',
        patch: 'cookiy_quant_survey_patch',
        report: 'cookiy_quant_survey_report',
        results: 'cookiy_quant_survey_results',
        stats: 'cookiy_quant_survey_stats',
      };
      const tool = map[sub];
      if (!tool) die('quant list|create|detail|patch|report|results|stats');
      const body = { ...pickSnake(a, ['survey_id', 'study_id', 'include_structure', 'structure_presentation', 'query', 'cursor', 'limit']) };
      if (a.json) Object.assign(body, JSON.parse(a.json));
      renderResult(await ctx.invoke(tool, body));
      return;
    }

    if (cmd === 'billing') {
      const [sub, ...btail] = tail;
      const a = parseArgs(btail);
      if (sub === 'balance') {
        renderResult(await ctx.invoke('cookiy_balance_get', {}));
        return;
      }
      if (sub === 'checkout') {
        const body = {
          ...pickSnake(a, ['amount_cents']),
          ...(a.json ? JSON.parse(a.json) : {}),
        };
        if (body.amount_cents === undefined) die('billing checkout requires --amount-cents or --json with amount_cents');
        body.amount_cents = Number(body.amount_cents);
        renderResult(await ctx.invoke('cookiy_billing_cash_checkout', body));
        return;
      }
      die('billing balance|checkout');
    }

    die(`Unknown command: ${cmd}\n${usage()}`);
  } catch (err) {
    die(err?.message || String(err), 1);
  }
}

main(process.argv.slice(2)).catch((e) => {
  console.error(e);
  die(e?.message || String(e), 1);
});
