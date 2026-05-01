#!/usr/bin/env python3
"""
Cookiy CLI End-to-End Test — Preview/S Environment.

Single-file script that exhaustively tests all 29 CLI leaf commands against
the selected REST v1 backend. Defaults to preview; set COOKIY_SERVER_URL to
target s/prod. Goes further than schema checks:

  - Self-bootstraps cookiy-cli via npm (install if missing, update each run)
  - Opens SSH tunnel to preview Postgres (hardcoded ~/.ssh/prod-pem.pem)
  - Tops up wallet balance via raw SQL if below threshold ($500 chunks)
  - Creates a fresh healthcare study (fixed well-designed query) each run
  - Runs read-only tests in parallel (ThreadPoolExecutor)
  - Runs paid tests sequentially, asserting balance-diff + transaction-row
  - Runs failure-path tests (401/402/404/409/422/timeout/missing-arg)
  - Restores mutated state (token, balance) via try/finally + atexit hooks
  - Writes a full markdown report (every CLI call + response captured)

Prerequisites (for internal Cookiy team members):
  - Node.js 18+ on PATH (e.g. via nvm install 22)
  - ~/.cookiy/token.txt  — OAuth access token for preview account
  - ~/.ssh/prod-pem.pem  — AWS bastion key (chmod 400)
  - Company VPN / whitelisted IP (for bastion access)
  - Wallet with some balance (auto-topped up via DB if < $50)

Everything else (SSH hosts, DB creds, tunnel ports, test fixtures) is
hardcoded in this file.

Usage:
    COOKIY_SERVER_URL=https://preview-api.cookiy.ai python3 cli_e2e_test.py
    COOKIY_SERVER_URL=https://s-api.cookiy.ai python3 cli_e2e_test.py
    python3 cli_e2e_test.py                 # run everything (~$21, full flow)
    python3 cli_e2e_test.py -v              # verbose (per-test timings)
    python3 cli_e2e_test.py -k billing      # filter by test name substring
    python3 cli_e2e_test.py --reuse-study 019c...  # skip study create

Install/upgrade cookiy-cli manually (optional — script does it automatically):
    npm install -g cookiy-cli
    npm update  -g cookiy-cli
"""
from __future__ import annotations

import argparse
import atexit
import base64
import fcntl
import hashlib
import hmac
import json
import os
import re
import signal
import socket
import struct
import subprocess
import sys
import textwrap
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

import psycopg2
import psycopg2.extras

# =============================================================================
# Configuration (all hardcoded for local use)
# =============================================================================

SERVER_URL = os.environ.get("COOKIY_SERVER_URL", "https://preview-api.cookiy.ai")
# CLI_BIN is resolved at runtime by ensure_cookiy_cli() — installs/updates
# cookiy-cli globally via npm, then returns absolute path.
CLI_BIN: str = ""  # set by main()
MIN_NODE_MAJOR = 18
CONTINUE_AFTER_RECRUIT_FAILURE = False

# Pin tests to this account (looked up by email in preview DB every run).
# The script generates a fresh 1-hour compact-cli-token each run signed with
# the preview `jwt_secret`; no hardcoded bearer to rot.
TEST_USER_EMAIL = "yupeng@cookiy.com"
TOKEN_LIFETIME_SECONDS = 3600  # 1 hour, plenty for one test run
# Matches `jwt_secret=...` in /Users/yupeng/Downloads/cookiy/cookiy-code/.preview-remote.env
# (verified in packages/back-end/vovey-modules/src/auth/attach-user.middleware.ts
#  — server reads process.env.jwt_secret and accepts both JWT + compact `cky_` tokens)
PREVIEW_JWT_SECRET = "secretjwt2025local2026"
TOKEN_PATH = Path.home() / ".cookiy" / "token.txt"

# SSH tunnel
# Two PEMs as of 2026-04 rotation: jump key for the public bastion,
# target key for the private host inside the VPC. Both default to
# ~/Downloads/ (where db-jump.sh lives) but the env vars override.
SSH_JUMP_KEY = Path(
    os.environ.get("ProdJumpPem")
    or os.environ.get("COOKIY_PROD_JUMP_PEM")
    or str(Path.home() / "Downloads" / "prod-pem.pem")
)
SSH_TARGET_KEY = Path(
    os.environ.get("ProdTargetPem")
    or os.environ.get("COOKIY_PROD_TARGET_PEM")
    or str(Path.home() / "Downloads" / "prod-machine-access.pem")
)
BASTION = "ec2-user@13.221.50.72"
JUMP_HOST = "ec2-user@10.0.137.197"
DB_INTERNAL_HOST = "10.0.141.54"
DB_PORT = 5432
TUNNEL_LOCAL_PORT = 15432  # do NOT collide with a running `npm run preview:tunnel`

# DB creds (preview)
DB_USER = "cookiy_code"
DB_PASS = "cookiy$$$20250928"
VOVEY_DB = "vovey-prod"

# Wallet top-up
TOPUP_AMOUNT_CENTS = 50_000  # $500 per top-up
MIN_BALANCE_CENTS = 5_000    # top up when balance < $50

# Expected prices (from `billing price-table`)
PRICE_DISCUSSION_GUIDE = 20
PRICE_SYNTHETIC = 20
PRICE_REPORT = 30

# Fixed healthcare study query — deterministic content each run
STUDY_QUERY = textwrap.dedent("""
    How Americans pay for and utilize their healthcare system.

    Focus areas:
    - Access to care: emergency, preventive, and chronic-condition care
    - Affordability concerns: insurance premiums, out-of-pocket costs,
      surprise bills, medical debt
    - Trust in providers, hospitals, and the healthcare system overall
    - Experiences with telehealth vs in-person visits
    - How people choose primary care physicians and specialists
    - Workplace-sponsored insurance vs individual marketplace vs uninsured

    Target participants: US adults aged 25-65 who have navigated the
    healthcare system in the last 12 months.

    Interview length: 30 minutes. 10 participants. Mixed demographics.
""").strip()

STUDY_LANGUAGE = "en"

# =============================================================================
# State
# =============================================================================

class SkipTest(Exception):
    """Raise from within a test to explicitly skip (instead of fail).
    register_test routes this to REGISTRY.skipped with no ✗ mark."""


# =============================================================================
# Helpers used by TestRegistry.write_contract_md (deterministic, no LLM)
# =============================================================================


def _parse_required_flags_per_command(
    src_dir: Path | None,
) -> dict[tuple[str, ...], set[str]]:
    """Parse cookiy-cli/src/commands/*.ts → map of command_path → required flags.

    Each key is a tuple like ('study', 'guide', 'update'); value is the set of
    `--flag` names that the source declared via `.requiredOption()`.

    The walker tracks variable assignments like
        `const guide = study.command("guide")`
    so nested chains (`guide.command("get")`) resolve to the full path
    ('study', 'guide', 'get'). Falls back gracefully when the source dir is
    missing — returns empty map (i.e. all flags shown as optional).

    Clone first if needed:
        gh repo clone cookiy-ai/cookiy-cli /tmp/cookiy-cli-src
    """
    result: dict[tuple[str, ...], set[str]] = {}
    if not src_dir or not src_dir.exists():
        return result
    # Allow whitespace (incl. newlines) between identifier and `.command(`
    # because the source uses chain-style `const study = program\n  .command("X")`.
    assign_re = re.compile(
        r'(?:const|let|var)\s+(\w+)\s*=\s*(\w+)\s*\.command\(\s*"([a-z-]+)"\s*\)'
    )
    chain_re = re.compile(
        r'\b(\w+)\s*\.command\(\s*"([a-z-]+)"\s*\)([\s\S]*?)\.action\(',
        re.MULTILINE,
    )
    req_re = re.compile(r'requiredOption\(\s*"(--[a-z][a-z0-9-]*)[" ]')
    for ts in src_dir.glob("*.ts"):
        text = ts.read_text()
        # 1. Build {var → cli_path_tuple} from assignment statements.
        var_to_path: dict[str, tuple[str, ...]] = {"program": ()}
        for m in assign_re.finditer(text):
            var, parent_var, cmd = m.group(1), m.group(2), m.group(3)
            parent_path = var_to_path.get(parent_var, ())
            var_to_path[var] = parent_path + (cmd,)
        # 2. For each `VAR.command("X")...action(` chain, attribute its
        #    requiredOptions to the resolved full path.
        for m in chain_re.finditer(text):
            parent_var, cmd, block = m.group(1), m.group(2), m.group(3)
            path = var_to_path.get(parent_var, (parent_var,)) + (cmd,)
            required = {rm.group(1) for rm in req_re.finditer(block)}
            if required:
                result[path] = required
    return result


_OPTION_LINE_RE = re.compile(
    r"^\s+(--[a-z][a-z0-9-]*)(?:\s+<([^>]+)>)?\s+(.+?)\s*$"
)


def _parse_help_options(help_text: str, required_flags: set[str]) -> list[dict]:
    """Parse `--help` output into list of {flag, type, required, description}.

    `required_flags` is the per-command set looked up from the source-derived
    map; pass an empty set to mark everything optional.
    """
    options: list[dict] = []
    in_opts = False
    for line in help_text.splitlines():
        if line.strip().lower() in ("options:", "选项:"):
            in_opts = True
            continue
        if not in_opts:
            continue
        if line and not line.startswith(" "):
            in_opts = False
            continue
        m = _OPTION_LINE_RE.match(line)
        if not m:
            continue
        flag, ty, desc = m.group(1), m.group(2), m.group(3).strip()
        if flag == "--help":
            continue
        options.append({
            "flag": flag,
            "type": ty or "boolean",
            "required": flag in required_flags,
            "description": desc,
        })
    return options


def _shape_of(data: Any, depth: int = 0, max_depth: int = 6) -> dict:
    if data is None:
        return {"type": "null"}
    if isinstance(data, bool):
        return {"type": "bool"}
    if isinstance(data, int):
        return {"type": "int", "sample": str(data)}
    if isinstance(data, float):
        return {"type": "number", "sample": str(data)}
    if isinstance(data, str):
        return {
            "type": "string",
            "sample": (data[:80] + "…") if len(data) > 80 else data,
        }
    if isinstance(data, list):
        if depth >= max_depth or not data:
            return {"type": "array", "items": None}
        return {
            "type": "array",
            "items": _shape_of(data[0], depth + 1, max_depth),
            "len": len(data),
        }
    if isinstance(data, dict):
        if depth >= max_depth:
            return {"type": "object", "truncated": True}
        return {
            "type": "object",
            "fields": {k: _shape_of(v, depth + 1, max_depth) for k, v in data.items()},
        }
    return {"type": str(type(data).__name__)}


def _flatten_shape(shape: dict, prefix: str = "") -> list[tuple[str, str, str]]:
    """Walk shape into rows: (field_path, type, sample)."""
    rows: list[tuple[str, str, str]] = []
    t = shape.get("type")
    if t == "object" and "fields" in shape:
        for k, child in shape["fields"].items():
            child_path = f"{prefix}.{k}" if prefix else k
            rows.extend(_flatten_shape(child, child_path))
    elif t == "array":
        items = shape.get("items")
        if isinstance(items, dict):
            rows.extend(_flatten_shape(items, f"{prefix}[]"))
        else:
            rows.append((prefix or "(root)", "array<empty>", ""))
    else:
        sample = str(shape.get("sample", "")) if shape.get("sample") is not None else ""
        rows.append((prefix or "(root)", t or "?", sample))
    return rows


# Default location for cookiy-cli source — used to detect required flags.
DEFAULT_CLI_SRC_DIR = Path("/tmp/cookiy-cli-src/src/commands")


@dataclass
class TestResult:
    name: str
    passed: bool
    message: str
    duration_ms: int = 0
    details: str | None = None
    # Populated when CLI is invoked inside a test (for report generation)
    cli_invocations: list[dict] = field(default_factory=list)
    assertions: list[str] = field(default_factory=list)


@dataclass
class RunContext:
    """Shared state across tests."""
    db_conn: Any = None
    user_id: str = ""
    original_balance_cents: int = 0
    # Fixtures created during the run
    study_id: str = ""        # used by Group A read-only tests (points at flow study if flow ran, else seed)
    flow_study_id: str = ""   # created by paid_full_study_flow Step 1
    survey_id: str = ""
    # Pre-existing seed IDs (for read-only tests that need historical data)
    seed_study_id: str = "019c51ab-cb2b-7094-a59f-e9d12e18ffc9"
    seed_interview_id: str = "019d0506-2a2a-76aa-bdf2-e0c25e7a51b8"
    seed_survey_id: str = "939797"
    # Config flags
    verbose: bool = False


class TestRegistry:
    def __init__(self):
        self.results: list[TestResult] = []
        self.skipped: list[str] = []  # ["name (reason)", ...]
        self.verbose = False
        self.filter_pattern: str | None = None
        self._lock = __import__("threading").Lock()

    def record(self, r: TestResult):
        with self._lock:
            self.results.append(r)
            marker = "✓" if r.passed else "✗"
            msg = f"  {marker} {r.name}"
            if r.duration_ms:
                msg += f"  ({r.duration_ms}ms)"
            if not r.passed:
                msg += f"  — {r.message}"
            print(msg, flush=True)
            if not r.passed and r.details and self.verbose:
                print(textwrap.indent(r.details, "      "), flush=True)

    def filter_matches(self, name: str) -> bool:
        return not self.filter_pattern or self.filter_pattern in name

    def summary(self) -> int:
        total = len(self.results)
        passed = sum(1 for r in self.results if r.passed)
        failed = total - passed
        print("\n" + "=" * 70)
        skip_suffix = f", {len(self.skipped)} skipped" if self.skipped else ""
        print(f"Results: {passed}/{total} passed, {failed} failed{skip_suffix}")
        if failed > 0:
            print("\nFailed:")
            for r in self.results:
                if not r.passed:
                    print(f"  ✗ {r.name}: {r.message}")
                    if r.details:
                        print(textwrap.indent(r.details[:500], "    "))
        print("=" * 70)
        return 0 if failed == 0 else 1

    def write_contract_md(self, path: Path, run_meta: dict,
                           cli_src_dir: Path | None = None):
        """Write a v1-cli-api-contract.md style markdown built deterministically
        from observed responses. Pairs each CLI command with its input flags
        (parsed from `cookiy <cmd> --help` + required-marker from cookiy-cli
        TS source if available) and output fields (walked from the actual JSON
        response captured in test runs).

        Unlike write_report() (which captures per-test flow), this produces a
        contract reference document — one row per CLI command, observed once.
        """
        # 1. Aggregate: {(cli_label, args_signature) -> first successful inv}
        observed: dict[str, dict] = {}
        for r in self.results:
            for inv in r.cli_invocations:
                label = self._cli_label(inv["args"])
                if not label:
                    continue
                # Prefer first successful invocation
                if inv["exit_code"] == 0 and label not in observed:
                    observed[label] = inv
                # Fallback: keep failure if no success yet
                elif label not in observed:
                    observed[label] = inv
        # 2. required flags map from cookiy-cli TS source (per command path)
        required_map = _parse_required_flags_per_command(cli_src_dir)
        # 3. Render
        md = [
            "# V1 CLI ↔ REST Contract — Observed",
            "",
            f"Auto-generated by `cli_e2e_test.py --contract` after a test run.",
            f"Each row reflects the actual response shape of a real CLI call.",
            "",
            f"- **Server**: `{run_meta.get('server', '?')}`",
            f"- **Started at**: {run_meta.get('started_at', '?')}",
            f"- **Test result**: "
            f"{sum(1 for r in self.results if r.passed)}/"
            f"{len(self.results)} passed",
            f"- **Required-flag source**: "
            f"`{cli_src_dir}` ({sum(len(v) for v in required_map.values())} required flags across "
            f"{len(required_map)} commands)" if cli_src_dir and required_map
            else "- **Required-flag source**: none (all flags shown as optional)",
            "",
            f"**说明**: input flags 来自 `cookiy <cmd> --help` + 解析 cookiy-cli "
            f"TS 源（`requiredOption()` patterns）；output 字段来自实际 JSON 响应。",
            "",
            "---",
            "",
            "## 总览表",
            "",
            "| # | CLI 命令 | exit | input flags | output keys |",
            "|---|---|---|---|---|",
        ]
        labels = sorted(observed.keys())
        for i, label in enumerate(labels, 1):
            inv = observed[label]
            flags = _parse_help_options(
                self._help_text(inv["args"]),
                required_map.get(self._cli_path_tuple(inv["args"]), set()),
            )
            try:
                parsed = json.loads(inv["stdout"]) if inv["stdout"].strip().startswith(
                    ("{", "[")
                ) else inv["stdout"]
            except json.JSONDecodeError:
                parsed = inv["stdout"]
            if isinstance(parsed, dict):
                n_out = str(len(parsed))
            elif isinstance(parsed, list):
                n_out = f"array[{len(parsed)}]"
            else:
                n_out = "—"
            status = "✅" if inv["exit_code"] == 0 else "❌"
            md.append(
                f"| {i} | `{label}` | {inv['exit_code']} {status} | "
                f"{len(flags)} | {n_out} |"
            )
        md.append("")
        md.append("---")
        md.append("")
        # 4. Per-command sections
        for i, label in enumerate(labels, 1):
            inv = observed[label]
            md.append(f"## {i}. `{label}`")
            md.append("")
            md.append(f"**Sample args**: `cookiy {' '.join(inv['args'])}`  ")
            md.append(f"**Exit code**: {inv['exit_code']}")
            md.append("")
            md.append("### Input flags (`--help` + source)")
            md.append("")
            help_text = self._help_text(inv["args"])
            flags = _parse_help_options(
                help_text,
                required_map.get(self._cli_path_tuple(inv["args"]), set()),
            )
            if flags:
                md.append("| Flag | 类型 | 必填 | 描述 |")
                md.append("|---|---|---|---|")
                for o in flags:
                    desc = o["description"].replace("|", "\\|")
                    md.append(
                        f"| `{o['flag']}` | `{o['type']}` | "
                        f"{'✅' if o['required'] else '—'} | {desc} |"
                    )
            else:
                md.append("_无 input flag。_")
            md.append("")
            md.append("### Output (observed)")
            md.append("")
            try:
                parsed = json.loads(inv["stdout"]) if inv["stdout"].strip().startswith(
                    ("{", "[")
                ) else inv["stdout"]
            except json.JSONDecodeError:
                parsed = inv["stdout"]
            if inv["exit_code"] != 0:
                md.append(f"_Run failed (exit={inv['exit_code']})._  ")
                if inv["stderr"].strip():
                    md.append(f"```\n{inv['stderr'].strip()[:500]}\n```")
            elif isinstance(parsed, str):
                head = parsed[:300].replace("|", "\\|")
                md.append(f"_Plain-text output (first 300 chars):_")
                md.append(f"```\n{head}\n```")
            elif isinstance(parsed, (dict, list)):
                rows = _flatten_shape(_shape_of(parsed))
                if rows:
                    md.append("| 字段 | 类型 | 样例 |")
                    md.append("|---|---|---|")
                    for fp, ty, sample in rows:
                        sample_md = sample.replace("|", "\\|").replace("\n", " ")[:80]
                        md.append(f"| `{fp}` | `{ty}` | {sample_md} |")
                else:
                    md.append("_Empty response._")
            md.append("")
            md.append("---")
            md.append("")
        path.write_text("\n".join(md))
        print(f"[contract] wrote {path} ({path.stat().st_size} bytes, "
              f"{len(labels)} commands)")

    @staticmethod
    def _cli_path_tuple(args: list[str]) -> tuple[str, ...]:
        """Sub-command path as a tuple (used for required-flag map lookup)."""
        non_flag = []
        for a in args:
            if a.startswith("-"):
                break
            non_flag.append(a)
        return tuple(non_flag)

    @staticmethod
    def _cli_label(args: list[str]) -> str | None:
        """Extract a stable command label from CLI args.

        Examples:
          ["study", "list", "--limit", "3"]              -> "study list"
          ["study", "guide", "get", "--study-id", "..."] -> "study guide get"
          ["billing", "balance"]                          -> "billing balance"
          ["save-token", "..."]                           -> "save-token"
          ["--version"]                                   -> "--version"
          ["-h"]                                          -> "-h"
        """
        non_flag = []
        for a in args:
            if a.startswith("-"):
                break
            non_flag.append(a)
        if not non_flag:
            # Pure flag invocation like `cookiy --version` / `cookiy -h`
            return args[0] if args else None
        return " ".join(non_flag)

    @staticmethod
    def _help_text(args: list[str]) -> str:
        """`cookiy <subcmd_path> --help` for the given sub-command."""
        sub = []
        for a in args:
            if a.startswith("-"):
                break
            sub.append(a)
        try:
            p = subprocess.run(
                [CLI_BIN] + sub + ["--help"],
                capture_output=True, text=True, timeout=5,
            )
            return p.stdout + "\n" + p.stderr
        except Exception:
            return ""

    def write_report(self, path: Path, run_meta: dict):
        """Write markdown report with every CLI call + response captured."""
        md = []
        total = len(self.results)
        passed = sum(1 for r in self.results if r.passed)
        failed = total - passed
        md.append(f"# Cookiy CLI E2E Test Report\n")
        md.append(f"**Run:** {run_meta['started_at']}  \n")
        md.append(f"**Server:** `{run_meta['server']}`  \n")
        md.append(f"**CLI:** `{run_meta['cli']}`  \n")
        md.append(f"**User:** `{run_meta['user_id']}`  \n")
        md.append(f"**Study:** `{run_meta['study_id']}`  \n")
        md.append(f"**Balance:** "
                  f"start ${run_meta['balance_start']/100:.2f} → "
                  f"end ${run_meta['balance_end']/100:.2f} "
                  f"(Δ ${(run_meta['balance_end']-run_meta['balance_start'])/100:+.2f})  \n")
        md.append(f"**Result:** **{passed}/{total} passed, {failed} failed**  \n")
        md.append(f"**Duration:** {run_meta['duration_s']:.1f}s  \n\n")
        md.append("---\n\n")

        for r in self.results:
            marker = "✅" if r.passed else "❌"
            md.append(f"## {marker} `{r.name}` ({r.duration_ms}ms)\n\n")
            if not r.passed:
                md.append(f"**Failure:** `{r.message}`\n\n")
                if r.details:
                    md.append(f"```\n{r.details[:2000]}\n```\n\n")
            for i, inv in enumerate(r.cli_invocations, 1):
                argstr = " ".join(repr(a) if " " in a else a for a in inv["args"])
                md.append(f"**CLI #{i}:** `cookiy {argstr}` "
                          f"→ exit `{inv['exit_code']}` ({inv['duration_ms']}ms)\n\n")
                if inv["stdout"].strip():
                    md.append("stdout:\n```json\n"
                              + inv["stdout"].strip()[:3000] + "\n```\n\n")
                if inv["stderr"].strip():
                    md.append("stderr:\n```\n"
                              + inv["stderr"].strip()[:1500] + "\n```\n\n")
            md.append("---\n\n")

        path.write_text("".join(md))
        print(f"\n[report] wrote {path} ({path.stat().st_size} bytes)")


REGISTRY = TestRegistry()


# =============================================================================
# CLI bootstrap — install/update cookiy-cli globally via npm
# =============================================================================

def ensure_cookiy_cli() -> str:
    """Install or update cookiy-cli globally. Return absolute path to `cookiy`."""
    # 1. Node version check (must be 18+)
    try:
        r = subprocess.run(["node", "--version"],
                           capture_output=True, text=True, timeout=5)
    except FileNotFoundError:
        raise RuntimeError(
            "Node.js not found on PATH. Install Node 18+ first "
            "(https://nodejs.org or `nvm install 22`)."
        )
    if r.returncode != 0:
        raise RuntimeError(f"`node --version` failed: {r.stderr}")
    major = int(r.stdout.strip().lstrip("v").split(".")[0])
    if major < MIN_NODE_MAJOR:
        raise RuntimeError(
            f"Node {MIN_NODE_MAJOR}+ required, found {r.stdout.strip()}"
        )

    # 2. Is cookiy-cli already installed globally?
    r = subprocess.run(
        ["npm", "list", "-g", "cookiy-cli", "--depth=0", "--json"],
        capture_output=True, text=True, timeout=30,
    )
    installed = False
    installed_version = None
    if r.returncode == 0:
        try:
            data = json.loads(r.stdout or "{}")
            deps = data.get("dependencies", {})
            if "cookiy-cli" in deps:
                installed = True
                installed_version = deps["cookiy-cli"].get("version")
        except json.JSONDecodeError:
            pass

    # 3. Install or update
    if not installed:
        print("[setup] cookiy-cli not installed — running: npm install -g cookiy-cli")
        r = subprocess.run(
            ["npm", "install", "-g", "cookiy-cli"],
            capture_output=True, text=True, timeout=300,
        )
        if r.returncode != 0:
            raise RuntimeError(
                f"`npm install -g cookiy-cli` failed:\n{r.stderr or r.stdout}"
            )
        print("[setup] install complete")
    else:
        print(f"[setup] cookiy-cli {installed_version} found — "
              f"running: npm update -g cookiy-cli")
        r = subprocess.run(
            ["npm", "update", "-g", "cookiy-cli"],
            capture_output=True, text=True, timeout=120,
        )
        if r.returncode != 0:
            # Update failure is non-fatal — we already have a version
            print(f"[setup] [warn] update failed (using existing): "
                  f"{r.stderr.strip()[:200]}", file=sys.stderr)

    # 4. Resolve binary path (don't rely on PATH — npm global bin may be
    #    outside the PATH seen by subprocess)
    #    Prefer `npm prefix -g` → <prefix>/bin/cookiy (macOS/Linux convention)
    r = subprocess.run(["npm", "prefix", "-g"],
                       capture_output=True, text=True, timeout=5)
    if r.returncode == 0 and r.stdout.strip():
        candidate = Path(r.stdout.strip()) / "bin" / "cookiy"
        if candidate.exists():
            return str(candidate)
    # Fallback: `which`
    r = subprocess.run(["which", "cookiy"],
                       capture_output=True, text=True, timeout=5)
    if r.returncode == 0 and r.stdout.strip():
        return r.stdout.strip()
    raise RuntimeError(
        "cookiy-cli was installed but binary not found. "
        "Check `npm prefix -g` and that its bin/ is on PATH."
    )


# =============================================================================
# SSH Tunnel manager
# =============================================================================

class Tunnel:
    """Starts the SSH tunnel in the background; kills it on exit."""

    def __init__(self):
        self.proc: subprocess.Popen | None = None
        self.own = False  # did we start it, or reuse existing?

    def _port_in_use(self) -> bool:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.3)
        try:
            return s.connect_ex(("127.0.0.1", TUNNEL_LOCAL_PORT)) == 0
        finally:
            s.close()

    def start(self):
        if self._port_in_use():
            print(f"[tunnel] port {TUNNEL_LOCAL_PORT} already in use — reusing")
            return

        proxy = (
            f"ssh -o StrictHostKeyChecking=accept-new "
            f"-o IdentitiesOnly=yes "
            f"-i {SSH_JUMP_KEY} -W %h:%p {BASTION}"
        )
        cmd = [
            "ssh",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=60",
            "-o", "ServerAliveCountMax=3",
            "-o", "IdentitiesOnly=yes",
            "-i", str(SSH_TARGET_KEY),
            "-o", f"ProxyCommand={proxy}",
            "-N", "-T",
            "-L", f"127.0.0.1:{TUNNEL_LOCAL_PORT}:{DB_INTERNAL_HOST}:{DB_PORT}",
            JUMP_HOST,
        ]
        print(f"[tunnel] opening local:{TUNNEL_LOCAL_PORT} → {DB_INTERNAL_HOST}:{DB_PORT}")
        self.proc = subprocess.Popen(
            cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            start_new_session=True,
        )
        self.own = True
        # Poll for port open (up to 15s)
        deadline = time.time() + 15
        while time.time() < deadline:
            if self._port_in_use():
                print(f"[tunnel] ready")
                return
            if self.proc.poll() is not None:
                err = self.proc.stderr.read().decode("utf-8", errors="replace")
                raise RuntimeError(f"SSH tunnel failed to start:\n{err}")
            time.sleep(0.3)
        raise RuntimeError("SSH tunnel did not open port within 15s")

    def stop(self):
        if self.proc and self.own:
            try:
                os.killpg(os.getpgid(self.proc.pid), signal.SIGTERM)
                self.proc.wait(timeout=5)
            except Exception:
                try:
                    self.proc.kill()
                except Exception:
                    pass
            print("[tunnel] closed")


# =============================================================================
# DB helper
# =============================================================================

def db_connect() -> Any:
    return psycopg2.connect(
        host="127.0.0.1", port=TUNNEL_LOCAL_PORT,
        user=DB_USER, password=DB_PASS, dbname=VOVEY_DB,
        connect_timeout=10,
    )


def db_user_id_by_email(conn, email: str) -> str:
    """Look up a user's UUID by email. Must be alive (deletedAt NULL)."""
    with conn.cursor() as cur:
        cur.execute(
            'SELECT id FROM "User" WHERE email = %s AND "deletedAt" IS NULL',
            (email,),
        )
        row = cur.fetchone()
    if not row:
        raise RuntimeError(
            f"User not found in preview DB for email {email!r}"
        )
    return str(row[0])


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def encode_legacy_jwt_token(user_id: str, exp_unix: int, secret: str) -> str:
    """Mirror the legacy HS256 JWT that cookiy's OAuth issuer produces.

    Why legacy JWT instead of new compact `cky_`? Preview runs older code
    until the compact-token rollout (PR merged to main, tagged
    [preview/20260427]). Until that lands on preview, only JWT verifies.
    The middleware's legacy branch (attach-user.middleware.ts) keeps
    verifying JWTs with tokenType=oauth_access indefinitely ("≤ 365 days
    after rollout"), so JWT remains safe long-term.

    Format: base64url(header).base64url(payload).base64url(HMAC-SHA256)
      header  = {"alg":"HS256","typ":"JWT"}
      payload = {"id":<uuid>, "tokenType":"oauth_access", "iat":..., "exp":...}
    """
    header = _b64url(b'{"alg":"HS256","typ":"JWT"}')
    payload = _b64url(json.dumps({
        "id": user_id,
        "tokenType": "oauth_access",
        "iat": int(time.time()),
        "exp": exp_unix,
    }, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header}.{payload}"
    sig = hmac.new(secret.encode("utf-8"),
                   signing_input.encode("utf-8"), hashlib.sha256).digest()
    return f"{signing_input}.{_b64url(sig)}"


def issue_fresh_token(conn) -> tuple[str, str]:
    """Resolve user by email, mint a 1-hour JWT, write to disk.

    Returns (token, user_id).
    """
    user_id = db_user_id_by_email(conn, TEST_USER_EMAIL)
    exp = int(time.time()) + TOKEN_LIFETIME_SECONDS
    token = encode_legacy_jwt_token(user_id, exp, PREVIEW_JWT_SECRET)
    TOKEN_PATH.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_PATH.write_text(token)
    return token, user_id


def db_get_balance(conn, user_id: str) -> int:
    with conn.cursor() as cur:
        cur.execute('SELECT balance FROM "User" WHERE id = %s', (user_id,))
        row = cur.fetchone()
        if not row:
            raise RuntimeError(f"User {user_id} not found in preview DB")
        return int(row[0])


def db_topup(conn, user_id: str, amount_cents: int):
    """Raw-SQL credit: INSERT Transaction + UPDATE User.balance atomically."""
    tx_id = str(uuid.uuid4())
    ts = int(time.time())
    with conn.cursor() as cur:
        cur.execute("BEGIN")
        cur.execute(
            '''
            INSERT INTO "Transaction"
                (id, "userId", amount, type, description, "createdAt")
            VALUES
                (%s::uuid, %s::uuid, %s, 'checkout',
                 %s, NOW())
            ''',
            (tx_id, user_id, amount_cents,
             f"cli_e2e_test manual topup [pid=cli_e2e_topup_{ts}]"),
        )
        cur.execute(
            'UPDATE "User" SET balance = balance + %s WHERE id = %s::uuid',
            (amount_cents, user_id),
        )
        conn.commit()
    print(f"[db] topped up ${amount_cents/100:.2f}, tx={tx_id[:8]}…")


def db_set_balance(conn, user_id: str, new_amount_cents: int) -> int:
    """Directly set balance. Returns OLD balance (so callers can restore)."""
    with conn.cursor() as cur:
        cur.execute('SELECT balance FROM "User" WHERE id = %s::uuid', (user_id,))
        row = cur.fetchone()
        if not row:
            raise RuntimeError(f"User {user_id} not found")
        old = int(row[0])
        cur.execute(
            'UPDATE "User" SET balance = %s WHERE id = %s::uuid',
            (new_amount_cents, user_id),
        )
        conn.commit()
        return old


def db_latest_debit(conn, user_id: str) -> dict | None:
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(
            '''SELECT id, amount, type, "studyId", "targetProductId",
                      description, "createdAt"
               FROM "Transaction"
               WHERE "userId" = %s::uuid AND amount < 0
               ORDER BY "createdAt" DESC LIMIT 1''',
            (user_id,),
        )
        row = cur.fetchone()
        return dict(row) if row else None


def db_wait_product_link(conn, tx_id: str, timeout_s: int = 30) -> str | None:
    """Poll until billing sweeper sets targetProductId (it runs every 60s)."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        with conn.cursor() as cur:
            cur.execute(
                'SELECT "targetProductId" FROM "Transaction" WHERE id = %s::uuid',
                (tx_id,),
            )
            row = cur.fetchone()
            if row and row[0]:
                return str(row[0])
        time.sleep(2)
    return None


# =============================================================================
# Token manager
# =============================================================================

class TokenMgr:
    """Token at ~/.cookiy/token.txt is always restored by minting a fresh
    compact token. No disk backup needed — we can always re-derive by DB
    lookup + HMAC sign. Requires an open DB connection."""

    @staticmethod
    def restore(conn):
        issue_fresh_token(conn)

    @staticmethod
    def invalidate():
        TOKEN_PATH.write_text("invalid_garbage_token_for_test")


# =============================================================================
# CLI wrapper
# =============================================================================

@dataclass
class CLIResult:
    exit_code: int
    stdout: str
    stderr: str
    parsed: Any | None

    @property
    def ok(self) -> bool:
        return self.exit_code == 0


import threading
_CURRENT_TEST = threading.local()


def run_cli(args: list[str], timeout_s: int = 120, env_overrides: dict | None = None) -> CLIResult:
    env = os.environ.copy()
    env["COOKIY_SERVER_URL"] = SERVER_URL
    if env_overrides:
        env.update(env_overrides)
    start = time.time()
    try:
        r = subprocess.run(
            [CLI_BIN] + args,
            capture_output=True, text=True, env=env, timeout=timeout_s,
        )
        parsed = None
        raw = (r.stdout or "").strip()
        if raw:
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                for line in raw.splitlines():
                    line = line.strip()
                    if line.startswith(("{", "[")):
                        try:
                            parsed = json.loads(line)
                            break
                        except json.JSONDecodeError:
                            continue
        result = CLIResult(r.returncode, r.stdout or "", r.stderr or "", parsed)
    except subprocess.TimeoutExpired:
        result = CLIResult(-1, "", "TIMEOUT", None)

    # Record invocation onto the currently-running test (thread-local)
    invocations = getattr(_CURRENT_TEST, "invocations", None)
    if invocations is not None:
        invocations.append({
            "args": args,
            "exit_code": result.exit_code,
            "duration_ms": int((time.time() - start) * 1000),
            "stdout": result.stdout[:4000],
            "stderr": result.stderr[:1000],
        })
    return result


# =============================================================================
# Assertion helpers
# =============================================================================

UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)


def assert_ok(result: CLIResult):
    if not result.ok:
        raise AssertionError(
            f"CLI exit {result.exit_code}; stderr={result.stderr!r}"
        )


def assert_json(result: CLIResult) -> Any:
    assert_ok(result)
    if result.parsed is None:
        raise AssertionError(f"not JSON; stdout={result.stdout[:200]!r}")
    return result.parsed


def assert_field(obj: dict, key: str, expected_type: type | tuple = None):
    if key not in obj:
        raise AssertionError(f"missing field {key!r}; have {list(obj.keys())}")
    if expected_type is not None and not isinstance(obj[key], expected_type):
        raise AssertionError(
            f"field {key!r} is {type(obj[key]).__name__}, "
            f"expected {expected_type}"
        )


def assert_uuid(value: str, field_name: str = "value"):
    if not UUID_RE.match(value):
        raise AssertionError(f"{field_name} is not a UUID: {value!r}")


def assert_fails(result: CLIResult, stderr_contains: str | None = None,
                  exit_code_nonzero: bool = True):
    if exit_code_nonzero and result.exit_code == 0:
        raise AssertionError(
            f"expected failure but CLI exit 0; stdout={result.stdout[:200]}"
        )
    if stderr_contains:
        combined = (result.stderr + result.stdout).lower()
        if stderr_contains.lower() not in combined:
            raise AssertionError(
                f"expected stderr to contain {stderr_contains!r}; "
                f"got stderr={result.stderr!r}"
            )


# Mirror REPORT_STAGE_VALUES from
# packages/back-end/cookiy-application/src/v1/schemas/report.schema.ts
# (or vovey-server/src/v1/schemas/report.schema.ts on preview/* branches).
# Server emits one of these four — never raw "generating"/"ready".
# `report_requested` was deprecated in favour of `report_generation_in_progress`
# so the shell `wait_for_report_then_link` polling contract aligns with
# `cookiy.sh:wait_for_report_then_link` (waits while
# `sources.report.status == "report_generation_in_progress"`).
REPORT_STATUS_VALUES = {
    "report_not_requested",
    "report_generation_in_progress",
    "report_ready",
    "report_failed",
}
# Mirror GUIDE_STATUS_VALUES — `queued` collapsed into `*_in_progress` so the
# shell `wait_for_guide` contract aligns (waits while
# `sources.guide.status == "guide_generation_in_progress"`).
GUIDE_STATUS_VALUES = {
    "guide_generation_in_progress",
    "guide_generation_failed",
    "guide_ready",
}
INTERVIEW_STATUS_VALUES = {"complete", "not_qualify", "in_process", "pause"}
PAGINATION_KEYS = ("total", "limit", "cursor", "next_cursor")


def assert_status_schema(data: dict):
    """Full `cookiy study status` schema assertion.

    Confirmed by architect (A1-A4):
      sources.interviews        → total / complete / not_qualify / in_process / pause
                                  (+ optional breakdown.{real, synthetic})
      sources.report.status     → ∈ REPORT_STATUS_VALUES
      sources.guide.status      → ∈ GUIDE_STATUS_VALUES
      sources.recruit           → status / completed_participants / target_participants
      sources.synthetic_interviews → target_nums / completed_nums
    Plus top-level target_sample_size (int).
    """
    assert_field(data, "study_id", str)
    assert_uuid(data["study_id"], "study_id")
    assert_field(data, "current_stage", str)
    assert_field(data, "target_sample_size", int)

    # Reject deprecated current_stage tokens; the shell relies on canonical
    # `*_generation_in_progress` to drive `wait_for_*` polling.
    if data["current_stage"] in {"report_requested", "guide_generation_queued"}:
        raise AssertionError(
            f"current_stage emits deprecated token {data['current_stage']!r}; "
            f"server should map to report_generation_in_progress / guide_generation_in_progress"
        )

    assert_field(data, "sources", dict)
    sources = data["sources"]

    # guide
    assert_field(sources, "guide", dict)
    assert_field(sources["guide"], "status", str)
    if sources["guide"]["status"] not in GUIDE_STATUS_VALUES:
        raise AssertionError(
            f"sources.guide.status must be in {GUIDE_STATUS_VALUES}, "
            f"got {sources['guide']['status']!r}"
        )

    # recruit (A3)
    assert_field(sources, "recruit", dict)
    assert_field(sources["recruit"], "status", str)
    assert_field(sources["recruit"], "completed_participants", int)
    # target_participants is null while recruit hasn't been launched yet
    # (V1ActivityRecruitSourceSchema declares it nullable per business logic).
    assert_field(sources["recruit"], "target_participants", (int, type(None)))

    # report (A2)
    assert_field(sources, "report", dict)
    assert_field(sources["report"], "status", str)
    if sources["report"]["status"] not in REPORT_STATUS_VALUES:
        raise AssertionError(
            f"sources.report.status must be in {REPORT_STATUS_VALUES}, "
            f"got {sources['report']['status']!r}"
        )

    # interviews (A1) — total/complete now roll up real + synthetic; per-status
    # buckets stay real-only (synthetic interviews don't carry not_qualify /
    # in_process / pause states). The `breakdown.{real, synthetic}` field is
    # the authoritative split for consumers that need it.
    assert_field(sources, "interviews", dict)
    iv = sources["interviews"]
    for k in ("total", "complete", "not_qualify", "in_process", "pause"):
        assert_field(iv, k, int)
        if iv[k] < 0:
            raise AssertionError(f"interviews.{k} negative: {iv[k]}")
    # Optional breakdown — when present, total/complete should equal
    # real + synthetic sums.
    if "breakdown" in iv:
        assert_field(iv["breakdown"], "real", dict)
        assert_field(iv["breakdown"], "synthetic", dict)
        real = iv["breakdown"]["real"]
        syn = iv["breakdown"]["synthetic"]
        if iv["total"] != real.get("total", 0) + syn.get("target_nums", 0):
            raise AssertionError(
                f"interviews.total ({iv['total']}) != real.total ({real.get('total')}) "
                f"+ synthetic.target_nums ({syn.get('target_nums')})"
            )
    # consistency: total == sum(real-status buckets) + synthetic.target_nums
    syn_target = sources.get("synthetic_interviews", {}).get("target_nums", 0)
    real_sum = iv["complete"] + iv["not_qualify"] + iv["in_process"] + iv["pause"]
    # When breakdown is absent, total may include synthetic without splitting
    # buckets — accept either: total == real_sum OR total == real_sum + syn_target.
    if iv["total"] not in (real_sum, real_sum + syn_target):
        raise AssertionError(
            f"interviews.total ({iv['total']}) != real_sum ({real_sum}) "
            f"and != real_sum + synthetic.target_nums ({real_sum + syn_target})"
        )

    # synthetic_interviews (A4)
    assert_field(sources, "synthetic_interviews", dict)
    si = sources["synthetic_interviews"]
    assert_field(si, "target_nums", int)
    assert_field(si, "completed_nums", int)
    if si["completed_nums"] > si["target_nums"]:
        raise AssertionError(
            f"synthetic completed_nums ({si['completed_nums']}) > "
            f"target_nums ({si['target_nums']})"
        )


def cli_wait_with_retry(
    cli_call: Callable[[], CLIResult],
    success: Callable[[dict], bool],
    total_max_s: int,
    timeout_keywords: tuple = ("timeout", "timed out"),
    on_not_ready_sleep_s: float = 2.0,
) -> dict:
    """Retry a `wait`-style CLI until success, tolerating single-call timeouts.

    Architect's design (answer C): single wait may return early when ready,
    OR timeout after --timeout-ms; script must re-invoke in a loop until
    success OR total_max_s exceeded.
    """
    deadline = time.time() + total_max_s
    last_err = ""
    while time.time() < deadline:
        r = cli_call()
        if r.ok and r.parsed and success(r.parsed):
            return r.parsed
        combined = (r.stderr + r.stdout).lower()
        # Single-call timeout → continue polling (expected path on long waits)
        if any(kw in combined for kw in timeout_keywords):
            last_err = f"single wait timed out, retrying"
            continue
        # Other failure → fatal (don't mask real errors as timeouts)
        if not r.ok:
            raise AssertionError(
                f"wait CLI failed: exit={r.exit_code}; "
                f"stderr={r.stderr.strip()[:300]}"
            )
        # OK exit but success() returned false → short sleep, retry
        last_err = f"not ready yet: {r.parsed}"
        time.sleep(on_not_ready_sleep_s)
    raise AssertionError(
        f"cli_wait_with_retry exceeded {total_max_s}s; last: {last_err}"
    )


def poll_until(
    fetch: Callable[[], Any],
    ready: Callable[[Any], bool],
    interval_s: float = 15.0,
    total_max_s: int = 600,
) -> Any:
    """Poll any getter until a ready predicate returns True (or timeout)."""
    deadline = time.time() + total_max_s
    last = None
    while time.time() < deadline:
        last = fetch()
        if ready(last):
            return last
        time.sleep(interval_s)
    raise AssertionError(f"poll_until exceeded {total_max_s}s; last={last!r}")


def register_test(name: str, fn: Callable, *args):
    """Run a test function and record result."""
    if not REGISTRY.filter_matches(name):
        return
    start = time.time()
    _CURRENT_TEST.invocations = []
    try:
        fn(*args)
        REGISTRY.record(TestResult(
            name, True, "OK", int((time.time() - start) * 1000),
            cli_invocations=list(_CURRENT_TEST.invocations),
        ))
    except SkipTest as e:
        with REGISTRY._lock:
            REGISTRY.skipped.append(f"{name} ({e})")
        if REGISTRY.verbose:
            print(f"  ⊘ {name} (skipped: {e})", flush=True)
    except AssertionError as e:
        REGISTRY.record(TestResult(
            name, False, str(e), int((time.time() - start) * 1000),
            cli_invocations=list(_CURRENT_TEST.invocations),
        ))
    except Exception as e:
        REGISTRY.record(TestResult(
            name, False, f"unexpected exception: {type(e).__name__}: {e}",
            int((time.time() - start) * 1000),
            details=__import__("traceback").format_exc(),
            cli_invocations=list(_CURRENT_TEST.invocations),
        ))
    finally:
        _CURRENT_TEST.invocations = None


# =============================================================================
# Fixture: create fresh healthcare study each run (fixed query)
# =============================================================================

def create_healthcare_study(ctx: RunContext) -> str:
    """Spend ~$0.20 to make a fresh study; return studyId."""
    r = run_cli(["study", "create", "--query", STUDY_QUERY], timeout_s=300)
    data = assert_json(r)
    # study create returns camelCase {studyId, status} (inconsistent w/ other
    # CLI commands that use snake_case study_id — known CLI quirk).
    sid_key = "studyId" if "studyId" in data else "study_id"
    assert_field(data, sid_key, str)
    assert_uuid(data[sid_key], sid_key)
    assert_field(data, "status", str)
    return data[sid_key]


def wait_for_guide_ready(study_id: str, timeout_s: int = 180) -> None:
    r = run_cli(["study", "guide", "wait",
                  "--study-id", study_id, "--timeout-ms", str(timeout_s * 1000)])
    data = assert_json(r)
    if data.get("status") != "guide_ready":
        raise AssertionError(f"guide not ready: {data}")


# =============================================================================
# Test groups
# =============================================================================

# -- Group A: read-only (parallel-safe) -------------------------------------

def test_cli_help():
    r = run_cli(["-h"])
    assert_ok(r)
    if "cookiy" not in r.stdout.lower():
        raise AssertionError("help text missing 'cookiy'")
    for cmd in ("study", "quant", "recruit", "billing"):
        if cmd not in r.stdout.lower():
            raise AssertionError(f"help missing command: {cmd}")


def test_cli_version():
    r = run_cli(["--version"])
    assert_ok(r)
    if not re.search(r"\d+\.\d+\.\d+", r.stdout):
        raise AssertionError(f"no version in stdout: {r.stdout!r}")


def test_study_list():
    r = run_cli(["study", "list", "--limit", "3"])
    data = assert_json(r)
    assert_field(data, "list", list)
    assert_field(data, "limit", int)
    assert_field(data, "total", int)
    for s in data["list"]:
        assert_field(s, "studyId", str)
        assert_uuid(s["studyId"], "studyId")
        assert_field(s, "projectName", str)
        assert_field(s, "createdAt", str)


def test_study_status(ctx: RunContext):
    r = run_cli(["study", "status", "--study-id", ctx.study_id])
    data = assert_json(r)
    if data["study_id"] != ctx.study_id:
        raise AssertionError(f"study_id echo mismatch: {data['study_id']}")
    # Full schema assertion — see assert_status_schema()
    assert_status_schema(data)
    # After creation + guide-wait, guide should be ready
    if data["sources"]["guide"].get("status") != "guide_ready":
        raise AssertionError(
            f"expected guide.status=guide_ready, got {data['sources']['guide']}"
        )


def test_study_guide_get(ctx: RunContext):
    r = run_cli(["study", "guide", "get", "--study-id", ctx.study_id])
    data = assert_json(r)
    assert_field(data, "revision", str)
    if not data["revision"].startswith("rev_"):
        raise AssertionError(f"revision not rev_*: {data['revision']}")
    assert_field(data, "discussion_guide", dict)
    g = data["discussion_guide"]
    assert_field(g, "research_overview", dict)
    assert_field(g["research_overview"], "project_name", str)
    assert_field(g["research_overview"], "sample_size", int)  # mod #2
    if g["research_overview"]["sample_size"] <= 0:
        raise AssertionError(
            f"research_overview.sample_size must be > 0, "
            f"got {g['research_overview']['sample_size']}"
        )
    assert_field(g, "core_research_questions", list)
    if len(g["core_research_questions"]) == 0:
        raise AssertionError("core_research_questions empty")
    assert_field(g, "participant_screening_criteria", dict)
    assert_field(g["participant_screening_criteria"], "screening_questions", list)
    assert_field(g, "interview_flow", dict)
    assert_field(g["interview_flow"], "sections", list)


def test_study_guide_wait_ready(ctx: RunContext):
    r = run_cli(["study", "guide", "wait",
                  "--study-id", ctx.study_id, "--timeout-ms", "5000"])
    data = assert_json(r)
    if data.get("status") != "guide_ready":
        raise AssertionError(f"expected guide_ready, got {data}")


def test_study_interview_list(ctx: RunContext):
    r = run_cli(["study", "interview", "list",
                  "--study-id", ctx.seed_study_id])
    data = assert_json(r)
    assert_field(data, "interviews", list)
    # mod #3: response must not paginate — reject non-null pagination markers
    for k in PAGINATION_KEYS:
        if k in data and data[k] is not None:
            raise AssertionError(
                f"interview list must not paginate — "
                f"found non-null {k!r}={data[k]!r}"
            )
    for iv in data["interviews"]:
        assert_field(iv, "interview_id", str)
        assert_uuid(iv["interview_id"], "interview_id")
        assert_field(iv, "status", str)
        if iv["status"] not in INTERVIEW_STATUS_VALUES:
            raise AssertionError(
                f"interview status must be in {INTERVIEW_STATUS_VALUES}, "
                f"got {iv['status']!r}"
            )
        assert_field(iv, "is_simulation", bool)


def test_study_interview_playback_url(ctx: RunContext):
    """Single-id mode returns a one-element list under the unified contract:
    `{interviews: [<single>], next_cursor: null}`."""
    r = run_cli([
        "study", "interview", "playback", "url",
        "--study-id", ctx.seed_study_id,
        "--interview-id", ctx.seed_interview_id,
    ])
    data = assert_json(r)
    assert_field(data, "interviews", list)
    if len(data["interviews"]) != 1:
        raise AssertionError(
            f"single-id playback should return 1 element, got {len(data['interviews'])}"
        )
    if data.get("next_cursor") is not None:
        raise AssertionError(
            f"next_cursor should be null in single-id mode, got {data['next_cursor']!r}"
        )
    item = data["interviews"][0]
    assert_field(item, "interview_id", str)
    assert_field(item, "playback_page_url", str)
    if not item["playback_page_url"].startswith("http"):
        raise AssertionError(f"not URL: {item['playback_page_url']}")
    assert_field(item, "playback_page_expires_at", str)


def test_study_interview_playback_content(ctx: RunContext):
    """Single-id mode returns a one-element list with transcript fields on
    item[0]."""
    r = run_cli([
        "study", "interview", "playback", "content",
        "--study-id", ctx.seed_study_id,
        "--interview-id", ctx.seed_interview_id,
    ])
    data = assert_json(r)
    assert_field(data, "interviews", list)
    if len(data["interviews"]) != 1:
        raise AssertionError(
            f"single-id playback content should return 1 element, got {len(data['interviews'])}"
        )
    item = data["interviews"][0]
    assert_field(item, "interview_id", str)
    assert_field(item, "transcript", list)
    if len(item["transcript"]) == 0:
        raise AssertionError("transcript empty")
    for entry in item["transcript"]:
        assert_field(entry, "role", str)
        if entry["role"] not in ("agent", "assistant", "user", "system"):
            raise AssertionError(f"bad role: {entry['role']}")
        assert_field(entry, "content", str)


def test_study_interview_playback_url_no_id(ctx: RunContext):
    """Batch mode (no --interview-id) returns paginated list, default limit 20.
    Validates #4 fix: server must accept missing interview_id and respond with
    `{interviews: [...], next_cursor: string|null}` instead of hanging or 400."""
    r = run_cli([
        "study", "interview", "playback", "url",
        "--study-id", ctx.seed_study_id,
    ])
    data = assert_json(r)
    assert_field(data, "interviews", list)
    if len(data["interviews"]) > 20:
        raise AssertionError(
            f"batch mode should default to limit=20, got {len(data['interviews'])}"
        )
    if "next_cursor" not in data:
        raise AssertionError(f"missing next_cursor; keys={list(data.keys())}")
    # next_cursor is string|null — type check covers both
    if data["next_cursor"] is not None and not isinstance(data["next_cursor"], str):
        raise AssertionError(
            f"next_cursor must be string|null, got {type(data['next_cursor']).__name__}"
        )
    # Each item should at least have interview_id + playback_page_url
    for item in data["interviews"]:
        assert_field(item, "interview_id", str)
        assert_field(item, "playback_page_url", str)


def test_study_interview_playback_content_no_id(ctx: RunContext):
    """Batch mode for content view — same shape, transcript fields optional
    per item to avoid N+1 fetch on large lists."""
    r = run_cli([
        "study", "interview", "playback", "content",
        "--study-id", ctx.seed_study_id,
    ])
    data = assert_json(r)
    assert_field(data, "interviews", list)
    if "next_cursor" not in data:
        raise AssertionError(f"missing next_cursor; keys={list(data.keys())}")
    for item in data["interviews"]:
        assert_field(item, "interview_id", str)


def test_study_report_content(ctx: RunContext):
    r = run_cli(["study", "report", "content",
                  "--study-id", ctx.seed_study_id])
    data = assert_json(r)
    assert_field(data, "study_id", str)
    assert_field(data, "report_status", str)
    for k in ("report_id", "generated_at", "title", "markdown"):
        if k not in data:
            raise AssertionError(f"missing {k}")


def test_study_report_link(ctx: RunContext):
    r = run_cli(["study", "report", "link",
                  "--study-id", ctx.seed_study_id])
    data = assert_json(r)
    assert_field(data, "study_id", str)
    assert_field(data, "report_status", str)
    if "share_url" not in data:
        raise AssertionError(f"missing share_url; keys={list(data.keys())}")
    # mod #4: share_password field should be present (may be null before ready)
    if "share_password" not in data:
        raise AssertionError(f"missing share_password; keys={list(data.keys())}")
    if data["report_status"] == "report_ready":
        # When ready, share_url and share_password should be non-null strings
        if not isinstance(data["share_url"], str) or not data["share_url"].startswith("http"):
            raise AssertionError(f"share_url when ready must be URL: {data['share_url']!r}")
        if not isinstance(data["share_password"], str):
            raise AssertionError(
                f"share_password when ready must be string: {data['share_password']!r}"
            )


def test_study_report_wait(ctx: RunContext):
    r = run_cli(["study", "report", "wait",
                  "--study-id", ctx.seed_study_id, "--timeout-ms", "5000"])
    data = assert_json(r)
    assert_field(data, "study_id", str)
    assert_field(data, "report_status", str)


def test_quant_list():
    r = run_cli(["quant", "list"])
    data = assert_json(r)
    assert_field(data, "surveys", list)
    for s in data["surveys"][:3]:
        assert_field(s, "survey_id", (str, int))
        assert_field(s, "title", str)


def test_quant_get(ctx: RunContext):
    r = run_cli(["quant", "get", "--survey-id", ctx.seed_survey_id])
    data = assert_json(r)
    assert_field(data, "survey_id", (str, int))
    # title + survey_format are nullable upstream (LimeSurvey may have no
    # title set yet, no format). language + survey_public_url are
    # guaranteed non-null by the LimeSurvey snapshot return type.
    assert_field(data, "title", (str, type(None)))
    assert_field(data, "survey_format", (str, type(None)))
    assert_field(data, "language", str)
    assert_field(data, "survey_public_url", str)
    assert_field(data, "creation_summary_markdown", str)


def test_quant_status(ctx: RunContext):
    r = run_cli(["quant", "status", "--survey-id", ctx.seed_survey_id])
    data = assert_json(r)
    assert_field(data, "survey_id", (str, int))
    assert_field(data, "survey", dict)
    for k in ("completed_responses", "incomplete_responses", "full_responses"):
        assert_field(data["survey"], k, int)


def test_quant_report(ctx: RunContext):
    r = run_cli(["quant", "report", "--survey-id", ctx.seed_survey_id])
    data = assert_json(r)
    assert_field(data, "survey_id", (str, int))
    assert_field(data, "completion_status", str)
    assert_field(data, "response_row_count", int)
    # completion_funnel is null when there are 0 responses or lastpage data
    # is too sparse to compute (server-side buildCompletionFunnel returns
    # null in those cases).
    assert_field(data, "completion_funnel", (dict, type(None)))
    assert_field(data, "question_summaries", list)


def test_quant_raw_response(ctx: RunContext):
    r = run_cli(["quant", "raw-response", "--survey-id", ctx.seed_survey_id])
    assert_ok(r)
    # CSV output; at minimum should have a header + 1 data row
    if len(r.stdout.strip().splitlines()) < 2:
        raise AssertionError("raw-response has no rows")


def test_billing_balance():
    r = run_cli(["billing", "balance"])
    data = assert_json(r)
    assert_field(data, "balance_summary", str)
    if not re.match(r"^-?\$\d", data["balance_summary"]):
        raise AssertionError(f"not currency: {data['balance_summary']}")


def test_billing_price_table():
    r = run_cli(["billing", "price-table"])
    data = assert_json(r)
    assert_field(data, "items", list)
    if len(data["items"]) == 0:
        raise AssertionError("price-table empty")
    joined_actions = " | ".join(item["action"].lower() for item in data["items"])
    for item in data["items"]:
        assert_field(item, "action", str)
        assert_field(item, "price", str)
        if not item["price"].startswith("$"):
            raise AssertionError(f"price not currency: {item['price']}")
    for required in ("discussion guide", "synthetic", "report", "qualitative", "quantitative"):
        if required not in joined_actions:
            raise AssertionError(
                f"missing action keyword: {required!r}; have: {joined_actions}"
            )


def test_billing_transactions():
    r = run_cli(["billing", "transactions", "--limit", "10"])
    data = assert_json(r)
    if not isinstance(data, list):
        raise AssertionError("expected array")
    for tx in data:
        assert_field(tx, "amount_cents", int)
        assert_field(tx, "type", str)
        assert_field(tx, "created_at", str)
        if tx["amount_cents"] < 0 and tx["type"] not in ("checkout", "off_session", "trial"):
            assert_field(tx, "quantity", int)


def test_billing_transactions_study_filter(ctx: RunContext):
    r = run_cli(["billing", "transactions",
                  "--limit", "5", "--study-id", ctx.seed_study_id])
    data = assert_json(r)
    if not isinstance(data, list):
        raise AssertionError("expected array")
    for tx in data:
        if "study_id" in tx and tx["study_id"] != ctx.seed_study_id:
            raise AssertionError(f"filter leak: {tx['study_id']}")


def test_study_upload():
    r = run_cli([
        "study", "upload",
        "--content-type", "image/png",
        "--image-url",
        "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
    ])
    data = assert_json(r)
    assert_field(data, "s3_key", str)
    if "/" not in data["s3_key"]:
        raise AssertionError(f"s3_key not a path: {data['s3_key']}")


# -- Group B: paid (sequential, balance-tracked) -----------------------------
#
# The 5 former paid cases (paid_study_create / paid_guide_update /
# paid_synthetic_user / paid_recruit_start / paid_report_generate) have been
# absorbed into `paid_full_study_flow` — see below. Group B now only contains
# cases that don't fit into the study lifecycle (billing checkout, quant).

def test_paid_billing_checkout(ctx: RunContext):
    """billing checkout: creates Stripe session (doesn't charge card)."""
    r = run_cli(["billing", "checkout", "--amount-usd-cents", "1000"])
    data = assert_json(r)
    assert_field(data, "checkout_url", str)
    if not data["checkout_url"].startswith("http"):
        raise AssertionError(f"not URL: {data['checkout_url']}")


def test_paid_quant_create(ctx: RunContext):
    """quant create: defines a small survey."""
    payload = json.dumps({
        "survey_title": f"cli_e2e_test healthcare {int(time.time())}",
        "languages": ["en"],
        "groups": [{
            "title": "Basics",
            "questions": [{
                "code": "insured",
                "type": "list_radio",
                "text": "Do you currently have health insurance?",
                "options": [
                    {"code": "A1", "label": "Yes, employer-provided"},
                    {"code": "A2", "label": "Yes, marketplace/ACA"},
                    {"code": "A3", "label": "Yes, Medicare/Medicaid"},
                    {"code": "A4", "label": "No"},
                ],
            }],
        }],
    })
    r = run_cli(["quant", "create", "--json", payload])
    data = assert_json(r)
    assert_field(data, "survey_id", (str, int))
    ctx.survey_id = str(data["survey_id"])


def test_paid_quant_update(ctx: RunContext):
    """quant update: modifies the survey we just created."""
    if not ctx.survey_id:
        raise AssertionError("ctx.survey_id empty; quant create must run first")
    patch = json.dumps({
        "survey": {"title": f"cli_e2e_test healthcare patched {int(time.time())}"}
    })
    r = run_cli([
        "quant", "update",
        "--survey-id", ctx.survey_id, "--json", patch,
    ])
    # update returns the patched survey (structure varies)
    assert_ok(r)
    if r.parsed is None:
        raise AssertionError("quant update returned no JSON")


# -- Paid full study flow (24 steps, sequential, 20-30 min, ~$20) -----------
#
# End-to-end lifecycle: create study → guide wait → patch → recruit x2 →
# synthetic → report → verify. Each step registers as its own test result so
# the report shows granular pass/fail. A step failure aborts later steps
# (via _FLOW_ABORT flag) to avoid cascade false-negatives.

_FLOW_ABORT = False
_FLOW_STATE: dict = {}


def _flow_step(name: str, fn: Callable, *args):
    """Register one flow step; skip remaining on any prior failure or skip.

    Any step failing OR raising SkipTest aborts the flow — later steps can't
    meaningfully run without the state the skipped step would have produced.
    """
    global _FLOW_ABORT
    full_name = f"flow_{name}"
    if _FLOW_ABORT:
        with REGISTRY._lock:
            REGISTRY.skipped.append(f"{full_name} (earlier flow step failed or skipped)")
        if REGISTRY.verbose:
            print(f"  ⊘ {full_name} (skipped: earlier flow failed/skipped)", flush=True)
        return
    results_before = len(REGISTRY.results)
    skipped_before = len(REGISTRY.skipped)
    register_test(full_name, fn, *args)
    added_result = len(REGISTRY.results) > results_before
    added_skip = len(REGISTRY.skipped) > skipped_before
    if added_skip:
        # SkipTest raised inside the step — abort remaining flow
        _FLOW_ABORT = True
    elif added_result and not REGISTRY.results[-1].passed:
        # Real failure — abort
        _FLOW_ABORT = True


def _flow_get_status(ctx: RunContext) -> dict:
    r = run_cli(["study", "status", "--study-id", ctx.flow_study_id])
    return assert_json(r)


def flow_step_01_create_study(ctx: RunContext):
    """Create new healthcare study. Assert -$0.20, tx type=discussion_guide,
    targetProductId gets linked by billing sweeper within 90s."""
    before = db_get_balance(ctx.db_conn, ctx.user_id)
    sid = create_healthcare_study(ctx)
    ctx.flow_study_id = sid
    ctx.study_id = sid  # Group A uses this study too
    after = db_get_balance(ctx.db_conn, ctx.user_id)
    delta = before - after
    if delta != PRICE_DISCUSSION_GUIDE:
        raise AssertionError(
            f"expected -${PRICE_DISCUSSION_GUIDE/100:.2f}, got -${delta/100:.2f}"
        )
    tx = db_latest_debit(ctx.db_conn, ctx.user_id)
    if not tx or tx["type"] != "discussion_guide":
        raise AssertionError(f"latest debit wrong: {tx}")
    if str(tx["studyId"]) != sid:
        raise AssertionError(f"tx studyId {tx['studyId']} != {sid}")
    _FLOW_STATE["guide_tx_id"] = str(tx["id"])


def flow_step_02_status_post_create(ctx: RunContext):
    """Right after create: guide generating, zero counts everywhere."""
    data = _flow_get_status(ctx)
    assert_status_schema(data)
    # guide should be `guide_generation_in_progress` (queued+running collapsed
    # into single in-progress token); occasionally it could already be
    # `guide_ready` if the LLM raced us, which is fine.
    if data["sources"]["guide"].get("status") == "guide_ready":
        pass  # raced — not an error
    iv = data["sources"]["interviews"]
    for k in ("total", "complete", "not_qualify", "in_process", "pause"):
        if iv[k] != 0:
            raise AssertionError(f"interviews.{k} should be 0 on fresh study, got {iv[k]}")
    si = data["sources"]["synthetic_interviews"]
    if si["target_nums"] != 0 or si["completed_nums"] != 0:
        raise AssertionError(f"synthetic should be 0/0 on fresh study, got {si}")
    if data["sources"]["recruit"]["completed_participants"] != 0:
        raise AssertionError("recruit.completed_participants should be 0")
    if data["sources"]["report"]["status"] != "report_not_requested":
        raise AssertionError(
            f"report.status should be 'report_not_requested', "
            f"got {data['sources']['report']['status']!r}"
        )


def flow_step_03_guide_wait_ready(ctx: RunContext):
    """Loop study guide wait up to 10 min, tolerating per-call timeouts."""
    def one_call():
        return run_cli([
            "study", "guide", "wait",
            "--study-id", ctx.flow_study_id,
            "--timeout-ms", "60000",
        ], timeout_s=90)
    final = cli_wait_with_retry(
        one_call,
        success=lambda d: d.get("status") == "guide_ready",
        total_max_s=600,
    )
    if final.get("status") != "guide_ready":
        raise AssertionError(f"expected status=guide_ready, got {final}")


def flow_step_04_status_post_guide_ready(ctx: RunContext):
    """Guide ready, other counts still 0."""
    data = _flow_get_status(ctx)
    assert_status_schema(data)
    if data["sources"]["guide"]["status"] != "guide_ready":
        raise AssertionError(
            f"guide.status should be 'guide_ready', got {data['sources']['guide']}"
        )


def flow_step_05_guide_get_baseline(ctx: RunContext):
    """Read sample_size + revision to use as baseline for patch."""
    r = run_cli(["study", "guide", "get", "--study-id", ctx.flow_study_id])
    data = assert_json(r)
    assert_field(data, "revision", str)
    assert_field(data["discussion_guide"]["research_overview"], "sample_size", int)
    _FLOW_STATE["old_revision"] = data["revision"]
    _FLOW_STATE["old_sample_size"] = data["discussion_guide"]["research_overview"]["sample_size"]


def flow_step_06_patch_sample_size(ctx: RunContext):
    """Patch sample_size to old+1 via nested-object format. Assert applied=true."""
    old_rev = _FLOW_STATE["old_revision"]
    old_sample = _FLOW_STATE["old_sample_size"]
    new_sample = old_sample + 1
    patch = json.dumps({"research_overview": {"sample_size": new_sample}})
    r = run_cli([
        "study", "guide", "update",
        "--study-id", ctx.flow_study_id,
        "--base-revision", old_rev,
        "--idempotency-key", str(uuid.uuid4()),
        "--json", patch,
        "--change-message", f"cli_e2e_test bump sample_size to {new_sample}",
    ])
    data = assert_json(r)
    assert_field(data, "revision", str)
    assert_field(data, "applied", bool)
    if not data["applied"]:
        raise AssertionError(f"applied=false: {data}")
    _FLOW_STATE["new_sample_size"] = new_sample


def flow_step_06b_patch_with_discussion_guide_wrapper(ctx: RunContext):
    """Validates #2 auto-unwrap: agents inferring PATCH shape from GET often
    wrap the patch under an extra `discussion_guide` key. Server must auto-
    unwrap when the patch's only top-level key is `discussion_guide`.

    Sends a wrapped patch + asserts applied=true. Bumps sample_size by +1
    again so step 07's verify check uses old+2 as the expected value.
    """
    # Re-fetch revision since step 06 changed it
    r = run_cli(["study", "guide", "get", "--study-id", ctx.flow_study_id])
    g = assert_json(r)
    cur_rev = g["revision"]
    new_sample = _FLOW_STATE["old_sample_size"] + 2
    # WRAPPED shape — without auto-unwrap this fails Zod validation in
    # CreateDiscussionGuideSchema (no `discussion_guide` key in spec).
    wrapped_patch = json.dumps({
        "discussion_guide": {"research_overview": {"sample_size": new_sample}}
    })
    r = run_cli([
        "study", "guide", "update",
        "--study-id", ctx.flow_study_id,
        "--base-revision", cur_rev,
        "--idempotency-key", str(uuid.uuid4()),
        "--json", wrapped_patch,
        "--change-message",
        f"cli_e2e_test #2 unwrap probe — wrapped patch to bump sample_size to {new_sample}",
    ])
    data = assert_json(r)
    assert_field(data, "applied", bool)
    if not data["applied"]:
        raise AssertionError(
            f"#2 auto-unwrap broken — wrapped {{discussion_guide: {{...}}}} patch "
            f"should be auto-unwrapped server-side and applied. response={data}"
        )
    _FLOW_STATE["new_sample_size"] = new_sample


def flow_step_07_verify_sample_size_applied(ctx: RunContext):
    """Re-fetch guide + status; both should reflect the new sample_size."""
    expected = _FLOW_STATE["new_sample_size"]
    r = run_cli(["study", "guide", "get", "--study-id", ctx.flow_study_id])
    g = assert_json(r)
    got_guide = g["discussion_guide"]["research_overview"]["sample_size"]
    if got_guide != expected:
        raise AssertionError(
            f"guide.sample_size: expected {expected}, got {got_guide}"
        )
    status = _flow_get_status(ctx)
    # O1: is status.target_sample_size derived from guide.sample_size?
    # Assert equality; if preview decouples them, fail loud and we revisit.
    if status["target_sample_size"] != expected:
        raise AssertionError(
            f"status.target_sample_size ({status['target_sample_size']}) != "
            f"guide.sample_size ({expected}) — architect O1 says to revisit"
        )


def flow_step_08_recruit_preview_round1(ctx: RunContext):
    """Preview round 1: get confirmation_token + cost_cents.
    Also verifies Q3 math: total_participants_after == prev + incremental."""
    # Get current target_participants from study status
    status = _flow_get_status(ctx)
    prev_target = status["sources"]["recruit"]["target_participants"]
    balance = db_get_balance(ctx.db_conn, ctx.user_id)

    r = run_cli([
        "recruit", "start",
        "--study-id", ctx.flow_study_id,
        "--plain-text",
        "US adults 25-65 who have used their health insurance in the past year.",
        "--incremental-participants", "1",
    ])
    data = assert_json(r)
    assert_field(data, "confirmation_token", str)
    assert_field(data, "cost_cents", int)
    assert_field(data, "incremental_participants", int)
    assert_field(data, "total_participants_after", int)

    # Math check (the bug the architect's image showed):
    if data["incremental_participants"] != 1:
        raise AssertionError(
            f"incremental_participants should echo 1, got {data['incremental_participants']}"
        )
    expected_total = prev_target + 1
    if data["total_participants_after"] != expected_total:
        raise AssertionError(
            f"MATH BUG: total_participants_after={data['total_participants_after']} "
            f"but expected prev_target({prev_target}) + incremental(1) = {expected_total}"
        )
    # cost_cents == 1 × PRICE_RECRUIT_QUAL (qualitative)
    expected_cost = 1 * 999
    if data["cost_cents"] != expected_cost:
        raise AssertionError(
            f"cost_cents={data['cost_cents']} but expected 1 × 999 = {expected_cost}"
        )
    # shortfall math
    expected_shortfall = max(0, data["cost_cents"] - balance)
    if "shortfall_cents" in data and data["shortfall_cents"] != expected_shortfall:
        raise AssertionError(
            f"shortfall_cents={data['shortfall_cents']} but expected "
            f"max(0, cost({data['cost_cents']}) - balance({balance})) = {expected_shortfall}"
        )

    _FLOW_STATE["token_1"] = data["confirmation_token"]
    _FLOW_STATE["cost_1"] = data["cost_cents"]
    _FLOW_STATE["prev_target_before_r1"] = prev_target


def flow_step_09_recruit_confirm_round1(ctx: RunContext):
    """Confirm: real Prolific spend. Balance delta == cost_1, tx type=recruit_*."""
    before = db_get_balance(ctx.db_conn, ctx.user_id)
    r = run_cli([
        "recruit", "start",
        "--study-id", ctx.flow_study_id,
        "--confirmation-token", _FLOW_STATE["token_1"],
    ])
    assert_json(r)
    after = db_get_balance(ctx.db_conn, ctx.user_id)
    delta = before - after
    if delta != _FLOW_STATE["cost_1"]:
        raise AssertionError(
            f"delta ${delta/100:.2f} != cost_1 ${_FLOW_STATE['cost_1']/100:.2f}"
        )
    tx = db_latest_debit(ctx.db_conn, ctx.user_id)
    if tx["type"] not in ("recruit_qualitative", "recruit_quantitative"):
        raise AssertionError(f"tx type: {tx['type']}")


def flow_step_10_status_post_r1(ctx: RunContext):
    """target_participants bumped by +1 from step 8 baseline."""
    data = _flow_get_status(ctx)
    assert_status_schema(data)
    expected = _FLOW_STATE["prev_target_before_r1"] + 1
    got = data["sources"]["recruit"]["target_participants"]
    if got != expected:
        raise AssertionError(
            f"target_participants expected {expected}, got {got}"
        )


def flow_step_11_recruit_preview_round2(ctx: RunContext):
    """Second incremental preview. total_participants_after math again."""
    status = _flow_get_status(ctx)
    prev_target = status["sources"]["recruit"]["target_participants"]
    r = run_cli([
        "recruit", "start",
        "--study-id", ctx.flow_study_id,
        "--plain-text",
        "US adults 25-65 who have used their health insurance in the past year.",
        "--incremental-participants", "1",
    ])
    data = assert_json(r)
    expected_total = prev_target + 1
    if data["total_participants_after"] != expected_total:
        raise AssertionError(
            f"MATH BUG (round 2): total_participants_after={data['total_participants_after']} "
            f"but expected {prev_target} + 1 = {expected_total}"
        )
    _FLOW_STATE["token_2"] = data["confirmation_token"]
    _FLOW_STATE["cost_2"] = data["cost_cents"]
    _FLOW_STATE["prev_target_before_r2"] = prev_target


def flow_step_12_recruit_confirm_round2(ctx: RunContext):
    before = db_get_balance(ctx.db_conn, ctx.user_id)
    r = run_cli([
        "recruit", "start",
        "--study-id", ctx.flow_study_id,
        "--confirmation-token", _FLOW_STATE["token_2"],
    ])
    assert_json(r)
    after = db_get_balance(ctx.db_conn, ctx.user_id)
    delta = before - after
    if delta != _FLOW_STATE["cost_2"]:
        raise AssertionError(
            f"delta ${delta/100:.2f} != cost_2 ${_FLOW_STATE['cost_2']/100:.2f}"
        )
    tx = db_latest_debit(ctx.db_conn, ctx.user_id)
    if tx["type"] not in ("recruit_qualitative", "recruit_quantitative"):
        raise AssertionError(f"tx type: {tx['type']}")


def flow_step_13_status_post_r2(ctx: RunContext):
    """Cumulative +2 from Step 8 baseline."""
    data = _flow_get_status(ctx)
    assert_status_schema(data)
    expected = _FLOW_STATE["prev_target_before_r1"] + 2
    got = data["sources"]["recruit"]["target_participants"]
    if got != expected:
        raise AssertionError(
            f"target_participants expected {expected}, got {got}"
        )


def flow_step_14_synthetic_start(ctx: RunContext):
    """Kick off 2 synthetic personas. Assert -$0.40, tx type=synthetic."""
    before = db_get_balance(ctx.db_conn, ctx.user_id)
    r = run_cli([
        "study", "run-synthetic-user", "start",
        "--study-id", ctx.flow_study_id,
        "--persona-count", "2",
    ])
    data = assert_json(r)
    assert_field(data, "study_id", str)
    after = db_get_balance(ctx.db_conn, ctx.user_id)
    delta = before - after
    expected = PRICE_SYNTHETIC * 2
    if delta != expected:
        raise AssertionError(
            f"delta ${delta/100:.2f} != expected 2×${PRICE_SYNTHETIC/100:.2f} = ${expected/100:.2f}"
        )
    tx = db_latest_debit(ctx.db_conn, ctx.user_id)
    if tx["type"] != "synthetic":
        raise AssertionError(f"tx type: {tx['type']}")


def flow_step_15_status_synthetic_kicked(ctx: RunContext):
    """target_nums >= 2 after kickoff. Worker is async — poll briefly.

    `study run-synthetic-user start` returns status=queued immediately; the
    worker inserts SyntheticUser/Interview rows that target_nums counts from
    a moment later. Single-shot read races the worker (observed on dev3:
    Step 14 returned batch_target=2 but Step 15 read target_nums=0 ~1s
    later). Poll until rows land or 30s elapses.
    """
    def fetch():
        d = _flow_get_status(ctx)
        assert_status_schema(d)
        return d
    def ready(d):
        return d["sources"]["synthetic_interviews"]["target_nums"] >= 2
    poll_until(fetch, ready, interval_s=2, total_max_s=30)


def flow_step_16_wait_synthetic_complete(ctx: RunContext):
    """Poll status until completed_nums >= target_nums (max 10 min)."""
    def fetch():
        return _flow_get_status(ctx)
    def ready(d):
        si = d["sources"]["synthetic_interviews"]
        return si["target_nums"] >= 2 and si["completed_nums"] >= si["target_nums"]
    poll_until(fetch, ready, interval_s=15, total_max_s=600)


def flow_step_17_report_pre_generate_check(ctx: RunContext):
    """content/link both return report_not_requested before we trigger generate."""
    r = run_cli(["study", "report", "content",
                  "--study-id", ctx.flow_study_id])
    c = assert_json(r)
    if c["report_status"] != "report_not_requested":
        raise AssertionError(
            f"content report_status should be 'report_not_requested', got {c['report_status']!r}"
        )
    r = run_cli(["study", "report", "link",
                  "--study-id", ctx.flow_study_id])
    l = assert_json(r)
    if l["report_status"] != "report_not_requested":
        raise AssertionError(
            f"link report_status should be 'report_not_requested', got {l['report_status']!r}"
        )


def flow_step_18_report_generate(ctx: RunContext):
    """Trigger generate WITHOUT --skip-synthetic-interview (want them included).
    Assert -$0.30, tx type=report. Fresh study → never idempotent."""
    before = db_get_balance(ctx.db_conn, ctx.user_id)
    r = run_cli([
        "study", "report", "generate",
        "--study-id", ctx.flow_study_id,
    ])
    data = assert_json(r)
    assert_field(data, "study_id", str)
    assert_field(data, "generation_request_id", str)
    assert_field(data, "report_status", str)
    after = db_get_balance(ctx.db_conn, ctx.user_id)
    delta = before - after
    if delta != PRICE_REPORT:
        raise AssertionError(
            f"report delta ${delta/100:.2f} != expected ${PRICE_REPORT/100:.2f} "
            f"(fresh study → no idempotent reuse expected)"
        )
    tx = db_latest_debit(ctx.db_conn, ctx.user_id)
    if tx["type"] != "report":
        raise AssertionError(f"tx type: {tx['type']}")


def flow_step_19_status_post_generate(ctx: RunContext):
    """report.status == 'report_generation_in_progress' (after generate, before ready).
    This validates #6: shell `wait_for_report_then_link` polls while
    `sources.report.status == "report_generation_in_progress"`, so the server
    must emit this token for both PENDING and GENERATING raw states (the old
    `report_requested` token is deprecated)."""
    data = _flow_get_status(ctx)
    assert_status_schema(data)
    if data["sources"]["report"]["status"] != "report_generation_in_progress":
        raise AssertionError(
            f"report.status should be 'report_generation_in_progress', "
            f"got {data['sources']['report']['status']!r}"
        )


def flow_step_20_report_wait_ready(ctx: RunContext):
    """Loop report wait up to 10 min."""
    def one_call():
        return run_cli([
            "study", "report", "wait",
            "--study-id", ctx.flow_study_id,
            "--timeout-ms", "60000",
        ], timeout_s=90)
    final = cli_wait_with_retry(
        one_call,
        success=lambda d: d.get("report_status") == "report_ready",
        total_max_s=600,
    )
    if final.get("report_status") != "report_ready":
        raise AssertionError(f"expected report_status=report_ready, got {final}")


def flow_step_21_status_report_ready(ctx: RunContext):
    """report.status == 'report_ready'."""
    data = _flow_get_status(ctx)
    assert_status_schema(data)
    if data["sources"]["report"]["status"] != "report_ready":
        raise AssertionError(
            f"report.status should be 'report_ready', got {data['sources']['report']['status']!r}"
        )


def flow_step_22_report_content_final(ctx: RunContext):
    """Ready state: report_id / generated_at / markdown all non-null."""
    r = run_cli(["study", "report", "content",
                  "--study-id", ctx.flow_study_id])
    data = assert_json(r)
    if data["report_status"] != "report_ready":
        raise AssertionError(f"report_status: {data['report_status']}")
    for k in ("report_id", "generated_at", "markdown"):
        if not data.get(k):
            raise AssertionError(f"{k} should be non-null when ready: {data.get(k)!r}")


def flow_step_23_report_link_final(ctx: RunContext):
    """Ready state: share_url + share_password both non-null strings."""
    r = run_cli(["study", "report", "link",
                  "--study-id", ctx.flow_study_id])
    data = assert_json(r)
    if data["report_status"] != "report_ready":
        raise AssertionError(f"report_status: {data['report_status']}")
    if not isinstance(data.get("share_url"), str) or not data["share_url"].startswith("http"):
        raise AssertionError(f"share_url invalid: {data.get('share_url')!r}")
    if not isinstance(data.get("share_password"), str):
        raise AssertionError(f"share_password not string: {data.get('share_password')!r}")


def flow_step_24_interview_list_final(ctx: RunContext):
    """No pagination keys (non-null); at least 2 is_simulation=true entries,
    all with status=complete (since step 16 waited for all synthetic done)."""
    r = run_cli(["study", "interview", "list",
                  "--study-id", ctx.flow_study_id])
    data = assert_json(r)
    assert_field(data, "interviews", list)
    for k in PAGINATION_KEYS:
        if k in data and data[k] is not None:
            raise AssertionError(f"non-null pagination key {k!r}={data[k]!r}")
    sim_entries = []
    for iv in data["interviews"]:
        assert_field(iv, "interview_id", str)
        assert_uuid(iv["interview_id"], "interview_id")
        assert_field(iv, "status", str)
        if iv["status"] not in INTERVIEW_STATUS_VALUES:
            raise AssertionError(f"invalid status {iv['status']!r}")
        assert_field(iv, "is_simulation", bool)
        if iv["is_simulation"]:
            sim_entries.append(iv)
    if len(sim_entries) < 2:
        raise AssertionError(
            f"expected >= 2 is_simulation entries, got {len(sim_entries)}"
        )
    for sim in sim_entries:
        if sim["status"] != "complete":
            raise AssertionError(
                f"synthetic interview should be 'complete' after step 16 wait, "
                f"got {sim['interview_id']} status={sim['status']!r}"
            )


def run_paid_full_study_flow(ctx: RunContext):
    """Entry point for the 24-step flow. Called from main()."""
    global _FLOW_ABORT, _FLOW_STATE
    _FLOW_ABORT = False
    _FLOW_STATE = {}
    steps = [
        ("step_01_create_study",              flow_step_01_create_study),
        ("step_02_status_post_create",        flow_step_02_status_post_create),
        ("step_03_guide_wait_ready",          flow_step_03_guide_wait_ready),
        ("step_04_status_post_guide_ready",   flow_step_04_status_post_guide_ready),
        ("step_05_guide_get_baseline",        flow_step_05_guide_get_baseline),
        ("step_06_patch_sample_size",         flow_step_06_patch_sample_size),
        ("step_06b_patch_unwrap_discussion_guide",
                                              flow_step_06b_patch_with_discussion_guide_wrapper),
        ("step_07_verify_sample_size",        flow_step_07_verify_sample_size_applied),
        ("step_08_recruit_preview_round1",    flow_step_08_recruit_preview_round1),
        ("step_09_recruit_confirm_round1",    flow_step_09_recruit_confirm_round1),
        ("step_10_status_post_r1",            flow_step_10_status_post_r1),
        ("step_11_recruit_preview_round2",    flow_step_11_recruit_preview_round2),
        ("step_12_recruit_confirm_round2",    flow_step_12_recruit_confirm_round2),
        ("step_13_status_post_r2",            flow_step_13_status_post_r2),
        ("step_14_synthetic_start",           flow_step_14_synthetic_start),
        ("step_15_status_synthetic_kicked",   flow_step_15_status_synthetic_kicked),
        ("step_16_wait_synthetic_complete",   flow_step_16_wait_synthetic_complete),
        ("step_17_report_pre_generate_check", flow_step_17_report_pre_generate_check),
        ("step_18_report_generate",           flow_step_18_report_generate),
        ("step_19_status_post_generate",      flow_step_19_status_post_generate),
        ("step_20_report_wait_ready",         flow_step_20_report_wait_ready),
        ("step_21_status_report_ready",       flow_step_21_status_report_ready),
        ("step_22_report_content_final",      flow_step_22_report_content_final),
        ("step_23_report_link_final",         flow_step_23_report_link_final),
        ("step_24_interview_list_final",      flow_step_24_interview_list_final),
    ]
    for name, fn in steps:
        _flow_step(name, fn, ctx)
        # Diagnostic mode only: synthetic + report (14-24) do not depend on
        # real recruitment, so a caller can continue after recruit cascade to
        # measure the rest of the CLI surface. Release-gate runs keep strict
        # fail-fast behavior by default.
        if CONTINUE_AFTER_RECRUIT_FAILURE and name == "step_13_status_post_r2" and _FLOW_ABORT:
            print("  [flow] resetting abort after recruit cascade — synthetic+report still run", flush=True)
            _FLOW_ABORT = False


# -- Group C: failure paths (sequential, state-mutating) -------------------

def test_fail_missing_required_arg():
    """study status without --study-id: client-side validation fails."""
    r = run_cli(["study", "status"])
    assert_fails(r, stderr_contains="required")


def test_fail_invalid_uuid():
    """study status with non-existent UUID: 404."""
    fake = "00000000-0000-0000-0000-000000000000"
    r = run_cli(["study", "status", "--study-id", fake])
    assert_fails(r)


def test_fail_bad_json_patch(ctx: RunContext):
    """guide update with malformed JSON: validation error."""
    r = run_cli([
        "study", "guide", "update",
        "--study-id", ctx.study_id,
        "--base-revision", "rev_0",
        "--idempotency-key", str(uuid.uuid4()),
        "--json", "{this is not json",
    ])
    assert_fails(r)


def test_fail_stale_revision(ctx: RunContext):
    """guide update with wrong base-revision: 409 conflict."""
    r = run_cli([
        "study", "guide", "update",
        "--study-id", ctx.study_id,
        "--base-revision", "rev_wrong_0000",
        "--idempotency-key", str(uuid.uuid4()),
        "--json", json.dumps({"research_overview.research_objective": "stale test"}),
        "--change-message", "cli_e2e_test stale",
    ])
    assert_fails(r)


def test_fail_guide_wait_timeout():
    """guide wait on a non-existent study with short timeout: should not wait forever."""
    fake = "00000000-0000-0000-0000-000000000000"
    r = run_cli([
        "study", "guide", "wait",
        "--study-id", fake, "--timeout-ms", "500",
    ], timeout_s=30)
    # Either 404 (study not found) or timeout — both are acceptable failures
    assert_fails(r)


def test_fail_insufficient_balance(ctx: RunContext):
    """Zero out balance, try study create, restore balance."""
    saved = db_set_balance(ctx.db_conn, ctx.user_id, 0)
    assert saved > 0, f"pre-test balance should be positive, was {saved}"
    try:
        r = run_cli(["study", "create", "--query",
                      "insufficient balance probe"],
                     timeout_s=60)
        assert_fails(r)
        combined = (r.stderr + r.stdout).lower()
        # Backend returns 402 / "insufficient balance" / "payment required"
        if not any(kw in combined for kw in
                   ("insufficient", "balance", "402", "payment", "credit")):
            raise AssertionError(
                f"error doesn't mention balance: {r.stderr!r}"
            )
    finally:
        restored = db_set_balance(ctx.db_conn, ctx.user_id, saved)
        if restored != 0:
            # Something else touched balance mid-test — log for awareness
            print(f"[warn] balance was {restored} during restore (expected 0)",
                  file=sys.stderr)


def test_fail_token_expired(ctx: RunContext):
    """Invalidate token, run any CLI, re-mint fresh via DB + HMAC."""
    try:
        TokenMgr.invalidate()
        r = run_cli(["study", "list", "--limit", "1"])
        assert_fails(r)
        combined = (r.stderr + r.stdout).lower()
        if not any(kw in combined for kw in
                   ("access denied", "token", "unauthorized", "401")):
            raise AssertionError(
                f"error doesn't mention auth: {r.stderr!r}"
            )
    finally:
        TokenMgr.restore(ctx.db_conn)


# =============================================================================
# Runner
# =============================================================================

def run_parallel(tests: list[tuple[str, Callable, tuple]], workers: int = 8):
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = [ex.submit(register_test, name, fn, *args)
                   for name, fn, args in tests if REGISTRY.filter_matches(name)]
        for f in as_completed(futures):
            f.result()


def run_sequential(tests: list[tuple[str, Callable, tuple]]):
    for name, fn, args in tests:
        if not REGISTRY.filter_matches(name):
            continue
        register_test(name, fn, *args)


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-k", "--filter", type=str, default=None,
                        help="only run tests whose name contains this substring")
    parser.add_argument("--reuse-study", type=str, default=None,
                        help="UUID of existing study for Group A read-only "
                             "tests. Ignored by the flow (which always creates new).")
    parser.add_argument("--report", type=str, default=None,
                        help="path for markdown report "
                             "(default: /tmp/cli_e2e_report_<ts>.md)")
    parser.add_argument("--contract", type=str, default=None,
                        help="path for v1-cli-api-contract-observed.md "
                             "(default: /tmp/cli_e2e_contract_<ts>.md). "
                             "Built from observed responses; required-flag "
                             "marking pulls from cookiy-cli TS source if "
                             "/tmp/cookiy-cli-src exists.")
    parser.add_argument("--cli-src", type=str, default=str(DEFAULT_CLI_SRC_DIR),
                        help=f"cookiy-cli source dir for required-flag detection "
                             f"(default: {DEFAULT_CLI_SRC_DIR}). Falls back to "
                             f"all-optional if missing.")
    parser.add_argument("--continue-after-recruit-failure", action="store_true",
                        help="diagnostic mode only: after recruit preview/confirm "
                             "cascade reaches step 13, continue synthetic/report "
                             "steps instead of treating the flow as failed-fast.")
    args = parser.parse_args()

    REGISTRY.verbose = args.verbose
    REGISTRY.filter_pattern = args.filter
    global CONTINUE_AFTER_RECRUIT_FAILURE
    CONTINUE_AFTER_RECRUIT_FAILURE = args.continue_after_recruit_failure

    started_at = datetime.now(timezone.utc).isoformat()
    wall_start = time.time()

    print(f"Cookiy CLI E2E Test")
    print(f"Server: {SERVER_URL}")
    print("=" * 70)

    # 0. Bootstrap cookiy-cli (install-once, update-each-run)
    global CLI_BIN
    CLI_BIN = ensure_cookiy_cli()
    print(f"CLI:    {CLI_BIN}")

    # 1. Open SSH tunnel (must come before token minting — token needs DB)
    tunnel = Tunnel()
    atexit.register(tunnel.stop)
    tunnel.start()

    # 2. Connect DB
    conn = db_connect()
    atexit.register(lambda: conn.close())

    # 3. Mint a fresh compact token for TEST_USER_EMAIL and write to disk.
    #    Re-issued every run — no hardcoded bearer to rot.
    token, user_id = issue_fresh_token(conn)
    print(f"[token] minted fresh cky_… for {TEST_USER_EMAIL} "
          f"(user={user_id}, exp=+{TOKEN_LIFETIME_SECONDS}s)")
    print(f"[user] {user_id}")
    balance = db_get_balance(conn, user_id)
    print(f"[balance] ${balance/100:.2f}")

    # 4. Top up if low — full flow always runs, so always ensure balance.
    if balance < MIN_BALANCE_CENTS:
        print(f"[balance] below ${MIN_BALANCE_CENTS/100:.2f}, topping up…")
        db_topup(conn, user_id, TOPUP_AMOUNT_CENTS)
        balance = db_get_balance(conn, user_id)
        print(f"[balance] now ${balance/100:.2f}")

    ctx = RunContext(
        db_conn=conn, user_id=user_id, original_balance_cents=balance,
        verbose=args.verbose,
    )

    # 5. Re-mint fresh token on any exit (crash-safe)
    atexit.register(lambda: TokenMgr.restore(conn))

    # 6. Safety net: if balance ends up anomalously below start, top up back.
    #    "Anomalous" = more than $40 lower than plausible spend for full flow:
    #    guide $0.20 + synthetic $0.40 (×2) + report $0.30 +
    #    recruit $9.99 × 2 rounds = ~$21. Double it for safety → $40.
    def _safety_restore_balance():
        try:
            final = db_get_balance(conn, user_id)
            max_expected_spend = 4000  # $40
            if final < ctx.original_balance_cents - max_expected_spend:
                diff = ctx.original_balance_cents - final
                print(f"[safety] balance dropped ${diff/100:.2f} — unexpected, "
                      f"topping up to at least ${ctx.original_balance_cents/100:.2f}",
                      file=sys.stderr)
                db_topup(conn, user_id, diff)
        except Exception as e:
            print(f"[safety] balance restore failed: {e}", file=sys.stderr)
    atexit.register(_safety_restore_balance)

    try:
        # ---- FLOW: paid_full_study_flow (24 steps, ~20-30 min, ~$21) ----
        # Runs FIRST so Group A has a fresh study with rich state (guide
        # ready, 2 recruit rounds, 2 completed synthetic, 1 report ready).
        # --reuse-study skips creation but still needs the rest of the flow's
        # state, so it just hot-swaps the study_id and waits for guide ready.
        if args.reuse_study:
            ctx.study_id = args.reuse_study
            ctx.flow_study_id = args.reuse_study
            print(f"[fixture] --reuse-study → {ctx.study_id}")
            print(f"[fixture] waiting for guide_ready…")
            wait_for_guide_ready(ctx.study_id, timeout_s=300)
        else:
            print("\n[FLOW] paid_full_study_flow (24 steps)")
            run_paid_full_study_flow(ctx)
            if ctx.flow_study_id:
                ctx.study_id = ctx.flow_study_id  # Group A uses this
            else:
                print("[flow] study creation failed — Group A falls back to seed")
                ctx.study_id = ctx.seed_study_id

        # ---- GROUP A: read-only, parallel ----
        print("\n[A] Read-only (parallel)")
        group_a = [
            ("cli_help",                        test_cli_help, ()),
            ("cli_version",                     test_cli_version, ()),
            ("study_list",                      test_study_list, ()),
            ("study_status",                    test_study_status, (ctx,)),
            ("study_upload",                    test_study_upload, ()),
            ("study_guide_get",                 test_study_guide_get, (ctx,)),
            ("study_guide_wait_ready",          test_study_guide_wait_ready, (ctx,)),
            ("study_interview_list",            test_study_interview_list, (ctx,)),
            ("study_interview_playback_url",    test_study_interview_playback_url, (ctx,)),
            ("study_interview_playback_content",test_study_interview_playback_content, (ctx,)),
            ("study_interview_playback_url_no_id",
                                                test_study_interview_playback_url_no_id, (ctx,)),
            ("study_interview_playback_content_no_id",
                                                test_study_interview_playback_content_no_id, (ctx,)),
            ("study_report_content",            test_study_report_content, (ctx,)),
            ("study_report_link",               test_study_report_link, (ctx,)),
            ("study_report_wait",               test_study_report_wait, (ctx,)),
            ("quant_list",                      test_quant_list, ()),
            ("quant_get",                       test_quant_get, (ctx,)),
            ("quant_status",                    test_quant_status, (ctx,)),
            ("quant_report",                    test_quant_report, (ctx,)),
            ("quant_raw_response",              test_quant_raw_response, (ctx,)),
            ("billing_balance",                 test_billing_balance, ()),
            ("billing_price_table",             test_billing_price_table, ()),
            ("billing_transactions",            test_billing_transactions, ()),
            ("billing_transactions_study_filter", test_billing_transactions_study_filter, (ctx,)),
        ]
        # Cheap stateless failure tests fit here too
        group_a.extend([
            ("fail_missing_required_arg",       test_fail_missing_required_arg, ()),
            ("fail_invalid_uuid",               test_fail_invalid_uuid, ()),
            ("fail_guide_wait_timeout",         test_fail_guide_wait_timeout, ()),
        ])
        run_parallel(group_a, workers=8)

        # ---- GROUP B (remainder): paid cases not covered by the flow ----
        # The 5 former paid cases (study_create, guide_update, synthetic_user,
        # recruit_start, report_generate) are inside the flow above.
        print("\n[B] Paid (not covered by flow)")
        group_b = [
            ("paid_billing_checkout",       test_paid_billing_checkout, (ctx,)),
            ("paid_quant_create",           test_paid_quant_create, (ctx,)),
            ("paid_quant_update",           test_paid_quant_update, (ctx,)),
        ]
        run_sequential(group_b)

        # ---- GROUP C: failure paths that mutate global state ----
        # Failure tests intentionally use seed_study_id (not flow_study_id)
        # so they don't depend on flow completing. fail_bad_json_patch and
        # fail_stale_revision target the guide update endpoint generically.
        print("\n[C] State-mutating failures (sequential, auto-restored)")
        fail_ctx = ctx  # fail_* use ctx.study_id; which is either flow or seed
        if not ctx.study_id:
            fail_ctx.study_id = ctx.seed_study_id
        group_c = [
            ("fail_bad_json_patch",         test_fail_bad_json_patch, (fail_ctx,)),
            ("fail_stale_revision",         test_fail_stale_revision, (fail_ctx,)),
            ("fail_insufficient_balance",   test_fail_insufficient_balance, (fail_ctx,)),
            ("fail_token_expired",          test_fail_token_expired, (fail_ctx,)),
        ]
        run_sequential(group_c)

    finally:
        final_balance = db_get_balance(conn, user_id)
        print(f"\n[balance] final ${final_balance/100:.2f} "
              f"(Δ ${(final_balance - ctx.original_balance_cents)/100:+.2f})")

        # Write markdown report (even if some tests failed)
        report_path = Path(args.report) if args.report else Path(
            f"/tmp/cli_e2e_report_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.md"
        )
        run_meta = {
            "started_at": started_at,
            "server": SERVER_URL,
            "cli": CLI_BIN,
            "user_id": user_id,
            "study_id": ctx.study_id,
            "balance_start": ctx.original_balance_cents,
            "balance_end": final_balance,
            "duration_s": time.time() - wall_start,
        }
        REGISTRY.write_report(report_path, run_meta)

        # Always also write the contract md (deterministic, post-run).
        contract_path = Path(args.contract) if args.contract else Path(
            f"/tmp/cli_e2e_contract_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.md"
        )
        REGISTRY.write_contract_md(contract_path, run_meta,
                                    cli_src_dir=Path(args.cli_src))

    sys.exit(REGISTRY.summary())


if __name__ == "__main__":
    main()
