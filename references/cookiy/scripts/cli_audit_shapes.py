#!/usr/bin/env python3
"""
Exercise cookiy.sh (all commands except recruit) and write Markdown + HTML:
collapsible per-command response *shape* trees AND the full JSON payload.

Command list mirrors cookiy.sh; some steps use dynamic IDs (cursor, guide revision,
survey id from quant create). Re-run after CLI changes.

Environment (optional):
  CLI                 path to cookiy.sh (default: alongside this script)
  COOKIY_SERVER_URL   API origin (default: https://preview-api.cookiy.ai)
  STUDY_ID            study with completed interview data (for read-only ops)
                      default: 019c51ab-cb2b-7094-a59f-e9d12e18ffc9 (Smart Home Speaker)
  WRITE_STUDY_ID      study safe to mutate (guide update / run-synthetic / report generate)
                      default: 019d950f-2493-712e-bf9e-f3526a4effca (CLI audit scratch)
  INTERVIEW_ID        interview with playback data
                      default: 019d0506-2a2a-76aa-bdf2-e0c25e7a51b8
  SURVEY_ID           existing quant survey for status/report/admin-link
                      default: 878381
  CLI_AUDIT_OUT       output .md path (default: references/cookiy/cli-response-structure-audit.md)
  CLI_AUDIT_HTML_OUT  output .html path (default: <md without .md>.html)

  CLI_AUDIT_SKIP_CHECKOUT=1         skip billing checkout (avoids real wallet charge)
  CLI_AUDIT_SKIP_SAVE_TOKEN=1       skip save-token (avoids network token validation)
  CLI_AUDIT_SKIP_SYNTHETIC=1        skip run-synthetic-user start (avoids paid synthetic interview)
  CLI_AUDIT_SKIP_REPORT_GENERATE=1  skip report generate (avoids paid report generation)
  CLI_AUDIT_REPORT_WAIT_MS          study report wait timeout (default 8000)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from typing import Any


def jshape(obj: Any) -> Any:
    if obj is None:
        return "null"
    if isinstance(obj, bool):
        return "boolean"
    if isinstance(obj, int) and not isinstance(obj, bool):
        return "number"
    if isinstance(obj, float):
        return "number"
    if isinstance(obj, str):
        return "string"
    if isinstance(obj, list):
        if len(obj) == 0:
            return ["array", "empty"]
        return ["array", jshape(obj[0])]
    if isinstance(obj, dict):
        return {k: jshape(v) for k, v in obj.items()}
    return "unknown"


def iter_json_values(text: str) -> list[Any]:
    s = text.strip()
    if not s:
        return []
    try:
        return [json.loads(s)]
    except json.JSONDecodeError:
        pass
    dec = json.JSONDecoder()
    i, n = 0, len(text)
    out: list[Any] = []
    while i < n:
        while i < n and text[i].isspace():
            i += 1
        if i >= n:
            break
        if text[i] not in "{[":
            break
        try:
            obj, j = dec.raw_decode(text, i)
        except json.JSONDecodeError:
            break
        out.append(obj)
        i = j
    return out


def format_shape_compact(
    shape: Any,
    *,
    depth: int = 0,
    max_depth: int = 5,
    max_keys: int = 24,
) -> str:
    pad = "  " * depth
    if depth >= max_depth:
        return pad + "…\n"
    if shape in ("string", "number", "boolean", "null", "unknown"):
        return pad + str(shape) + "\n"
    if isinstance(shape, str):
        return pad + shape + "\n"
    if isinstance(shape, list):
        if len(shape) >= 2 and shape[0] == "array":
            inner = shape[1]
            if inner == "empty":
                return pad + "array[]\n"
            return (
                pad
                + "array[\n"
                + format_shape_compact(inner, depth=depth + 1, max_depth=max_depth, max_keys=max_keys)
                + pad
                + "]\n"
            )
        return pad + json.dumps(shape, ensure_ascii=False) + "\n"
    if isinstance(shape, dict):
        if shape.get("kind") == "text":
            lines = [f"{pad}text ({shape.get('line_count', '?')} lines)"]
            if ips := shape.get("invalid_parameters_shape"):
                lines.append(pad + "invalid_parameters:")
                lines.append(
                    format_shape_compact(
                        ips,
                        depth=depth + 1,
                        max_depth=max_depth,
                        max_keys=max_keys,
                    ).rstrip("\n")
                )
            return "\n".join(lines) + "\n"
        keys = list(shape.keys())
        extra = ""
        if len(keys) > max_keys:
            keys = keys[:max_keys]
            extra = f"\n{pad}  … +{len(shape) - max_keys} more keys"
        parts: list[str] = []
        for k in keys:
            v = shape[k]
            if isinstance(v, (dict, list)) and depth + 1 < max_depth:
                parts.append(f"{pad}{k}:")
                parts.append(
                    format_shape_compact(
                        v,
                        depth=depth + 1,
                        max_depth=max_depth,
                        max_keys=max_keys,
                    ).rstrip("\n")
                )
            else:
                parts.append(f"{pad}{k}: {compact_inline(v)}")
        return "\n".join(parts) + extra + "\n"
    return pad + str(shape) + "\n"


def compact_inline(t: Any, max_keys: int = 12) -> str:
    if t in ("string", "number", "boolean", "null", "unknown"):
        return str(t)
    if isinstance(t, dict):
        ks = list(t.keys())
        if len(ks) > max_keys:
            return "object(" + ",".join(ks[:max_keys]) + f",…+{len(ks) - max_keys})"
        return "object(" + ",".join(ks) + ")"
    if isinstance(t, list):
        if len(t) >= 2 and t[0] == "array":
            if t[1] == "empty":
                return "array[]"
            return f"array[{compact_inline(t[1])}]"
        return json.dumps(t, ensure_ascii=False)
    return str(t)


def classify_non_json(text: str) -> Any:
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines:
        return "empty"
    base: dict[str, Any] = {"kind": "text", "line_count": len(lines)}
    if "Invalid parameters:" in text:
        idx = text.find("[")
        if idx >= 0:
            try:
                arr = json.loads(text[idx:])
                base["invalid_parameters_shape"] = jshape(arr)
            except json.JSONDecodeError:
                pass
    return base


def run_cli(cli: str, args: list[str]) -> tuple[int, str]:
    env = os.environ.copy()
    # Support both shell and Node.js CLI
    if cli.endswith(".js"):
        cmd = ["node", cli, *args]
    else:
        cmd = ["bash", cli, *args]
    p = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env,
    )
    combined = (p.stdout or "") + (p.stderr or "")
    return p.returncode, combined


def row_from_text(name: str, ec: int, text: str, cmd: list[str] | None = None) -> dict[str, Any]:
    parsed = iter_json_values(text)
    if parsed:
        shapes = [jshape(x) for x in parsed]
        kind = "json"
    else:
        shapes = classify_non_json(text)
        kind = "non_json"

    if kind == "json":
        if len(shapes) > 1:
            parts: list[str] = []
            for i, s in enumerate(shapes, 1):
                parts.append(f"── JSON value {i} ──")
                parts.append(format_shape_compact(s).rstrip("\n"))
            shape_compact = "\n".join(parts) + "\n"
        else:
            shape_compact = format_shape_compact(shapes[0])
    else:
        shape_compact = format_shape_compact(shapes)

    # For HTML: include a truncated pretty-printed JSON sample of the first value
    raw_sample = ""
    if kind == "json" and parsed:
        try:
            raw_sample = json.dumps(parsed[0], indent=2, ensure_ascii=False)
        except Exception:
            raw_sample = str(parsed[0])
    else:
        raw_sample = text.strip()
    # Truncate very large payloads for HTML display
    if len(raw_sample) > 8000:
        raw_sample = raw_sample[:8000] + "\n…(truncated)"

    return {
        "name": name,
        "cmd": cmd or [],
        "exit_code": ec,
        "response_kind": kind,
        "json_value_count": len(parsed) if kind == "json" else 0,
        "shape_compact": shape_compact,
        "raw_sample": raw_sample,
    }


def first_dict(text: str) -> dict[str, Any] | None:
    for v in iter_json_values(text):
        if isinstance(v, dict):
            return v
    return None


def extract_survey_id(text: str) -> str | None:
    for v in iter_json_values(text):
        if not isinstance(v, dict):
            continue
        for k in ("survey_id", "surveyId"):
            if k in v and v[k] is not None:
                return str(v[k])
        s = v.get("survey")
        if isinstance(s, dict):
            for k in ("survey_id", "surveyId", "id"):
                if k in s and s[k] is not None:
                    return str(s[k])
    return None


def extract_guide_revision(text: str) -> str | None:
    for v in iter_json_values(text):
        if isinstance(v, dict) and "revision" in v and v["revision"] is not None:
            return str(v["revision"])
    return None


def html_escape(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


CATEGORIES = [
    ("CLI basics", ("usage", "-h", "--version", "help", "save-token")),
    ("Study lifecycle", ("study list", "study status", "study create", "study upload")),
    ("Discussion guide", ("study guide",)),
    ("Interviews", ("study interview",)),
    ("Synthetic users", ("study run-synthetic",)),
    ("Report", ("study report",)),
    ("Quantitative survey", ("quant",)),
    ("Billing", ("billing",)),
]


def category_of(name: str) -> str:
    n = name.lower()
    for cat, prefixes in CATEGORIES:
        for p in prefixes:
            if n.startswith(p):
                return cat
    return "Other"


HTML_STYLE = """
:root {
  --ink: #0f172a;
  --muted: #475569;
  --line: #e2e8f0;
  --accent: #1e293b;
  --page: #ffffff;
  --panel: #f8fafc;
  --panel-dark: #f1f5f9;
  --del-bg: #fef2f2; --del-ink: #991b1b; --del-border: #fecaca;
  --add-bg: #ecfdf5; --add-ink: #065f46; --add-border: #a7f3d0;
  --keep-bg: #ffffff; --keep-ink: #0f172a;
  --skip-bg: #f8fafc; --skip-ink: #475569;
}
* { box-sizing: border-box; }
html, body { background: var(--page); color: var(--ink); }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC",
    "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
  font-size: 12px; line-height: 1.45; margin: 0; padding: 0;
}
.page { padding: 18px 18px 28px; max-width: 1040px; margin: 0 auto; }
.mono, code, pre { font-family: "SF Mono", Menlo, Consolas, monospace; }
header.doc { border-bottom: 2px solid var(--accent); padding-bottom: 10px; margin-bottom: 14px; }
header.doc h1 { font-size: 20px; margin: 0 0 4px; }
header.doc p { margin: 2px 0; color: var(--muted); font-size: 11px; }
header.doc p code { background: #eef2f7; padding: 0 3px; border-radius: 3px; color: var(--ink); }
.legend { margin-top: 6px; display: flex; gap: 8px; flex-wrap: wrap; font-size: 10.5px; color: var(--muted); }
.legend .swatch { display: inline-flex; align-items: center; gap: 4px; padding: 1px 6px; border-radius: 3px; border: 1px solid transparent; }
.legend .swatch.ok   { background: var(--add-bg); color: var(--add-ink); border-color: var(--add-border); }
.legend .swatch.fail { background: var(--del-bg); color: var(--del-ink); border-color: var(--del-border); }
.legend .swatch.skip { background: var(--skip-bg); color: var(--skip-ink); border: 1px dashed #c7cfdb; }
.divider {
  border-top: 2px solid var(--accent);
  padding-top: 8px; margin-top: 18px; margin-bottom: 8px;
}
.divider .title { font-size: 13px; font-weight: 700; color: var(--ink); }
.divider .sub { font-size: 11px; color: var(--muted); margin-top: 2px; }
section.tool {
  border: 1px solid var(--line); border-radius: 6px; overflow: hidden;
  margin: 10px 0; background: var(--page);
  break-inside: avoid; page-break-inside: avoid;
}
section.tool > header {
  display: flex; justify-content: space-between; align-items: baseline; gap: 12px;
  padding: 6px 10px; background: var(--panel); border-bottom: 1px solid var(--line);
}
section.tool > header h2 { margin: 0; font-size: 13px; font-weight: 600; display: flex; gap: 6px; align-items: baseline; flex-wrap: wrap; }
section.tool > header .cli { font-family: "SF Mono", Menlo, Consolas, monospace; color: var(--accent); }
section.tool > header .tool-id { font-family: "SF Mono", Menlo, Consolas, monospace; color: var(--muted); font-size: 11px; font-weight: 500; }
section.tool > header .summary { color: var(--muted); font-size: 10.5px; max-width: 55%; text-align: right; }
.badge { display: inline-block; font-size: 9.5px; font-weight: 600; padding: 1px 5px; border-radius: 3px; letter-spacing: 0.04em; text-transform: uppercase; margin-left: 2px; }
.badge.ok   { background: var(--add-bg); color: var(--add-ink); border: 1px solid var(--add-border); }
.badge.fail { background: var(--del-bg); color: var(--del-ink); border: 1px solid var(--del-border); }
.badge.skip { background: var(--skip-bg); color: var(--skip-ink); border: 1px dashed #c7cfdb; }
section.tool > .body { padding: 8px 10px; }
section.tool.fail > header { background: var(--del-bg); }
section.tool.fail { border-color: var(--del-border); }
section.tool.skip > header { background: var(--panel-dark); }
section.tool.skip { border-color: #d6dbe2; }
.cmd { font-family: "SF Mono", Menlo, Consolas, monospace; font-size: 10.5px; color: var(--accent); background: #eef2f7; padding: 4px 6px; border-radius: 3px; margin-bottom: 6px; word-break: break-all; }
.panes { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.pane h4 { margin: 0 0 3px; font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); font-weight: 600; }
.pane.single { grid-column: 1 / span 2; }
pre.shape, pre.raw {
  font-family: "SF Mono", Menlo, Consolas, monospace;
  font-size: 10.5px; line-height: 1.5; margin: 0;
  white-space: pre; word-break: normal; overflow-x: auto;
  padding: 6px 8px; border: 1px solid var(--line); border-radius: 4px;
}
pre.shape { background: var(--keep-bg); }
pre.raw { background: var(--panel); color: var(--muted); max-height: 240px; overflow-y: auto; white-space: pre-wrap; word-break: break-word; font-size: 10px; }
footer.doc { margin-top: 24px; border-top: 2px solid var(--accent); padding-top: 8px; color: var(--muted); font-size: 10.5px; }
@media print {
  @page { size: A4; margin: 12mm 10mm; }
  .page { padding: 0; max-width: none; }
  section.tool { break-inside: avoid; page-break-inside: avoid; }
  .divider { break-before: auto; }
  pre.raw { max-height: none; overflow: visible; }
}
"""


def tool_id_from_cmd(cmd: list[str]) -> str:
    """Rough CLI → MCP tool id lookup, best effort."""
    if not cmd:
        return ""
    joined = " ".join(cmd)
    if joined.startswith("study list"):
        return "cookiy_study_list"
    if joined.startswith("study create"):
        return "cookiy_study_create"
    if joined.startswith("study status"):
        return "cookiy_activity_get"
    if joined.startswith("study upload"):
        return "cookiy_media_upload"
    if joined.startswith("study guide get"):
        return "cookiy_guide_get"
    if joined.startswith("study guide update"):
        return "cookiy_guide_patch"
    if joined.startswith("study interview list"):
        return "cookiy_interview_list"
    if joined.startswith("study interview playback url"):
        return "cookiy_interview_playback_get · view=url"
    if joined.startswith("study interview playback content"):
        return "cookiy_interview_playback_get · view=transcript"
    if joined.startswith("study run-synthetic-user"):
        return "cookiy_simulated_interview_generate"
    if joined.startswith("study report generate"):
        return "cookiy_report_generate"
    if joined.startswith("study report content"):
        return "cookiy_report_content_get"
    if joined.startswith("study report link"):
        return "cookiy_report_share_link_get"
    if joined.startswith("study report wait"):
        return "cookiy_report_status + cookiy_report_share_link_get"
    if joined.startswith("quant list"):
        return "cookiy_quant_survey_list"
    if joined.startswith("quant create"):
        return "cookiy_quant_survey_create"
    if joined.startswith("quant get"):
        return "cookiy_quant_survey_detail"
    if joined.startswith("quant update"):
        return "cookiy_quant_survey_patch"
    if joined.startswith("quant status"):
        return "cookiy_quant_survey_status"
    if joined.startswith("quant report"):
        return "cookiy_quant_survey_report"
    if joined.startswith("quant raw-response"):
        return "cookiy_quant_survey_raw_responses"
    if joined.startswith("billing balance"):
        return "cookiy_balance_get"
    if joined.startswith("billing checkout"):
        return "cookiy_billing_cash_checkout"
    if joined.startswith("billing price-table"):
        return "cookiy_billing_price_table"
    if joined.startswith("billing transactions"):
        return "cookiy_billing_transactions"
    return ""


def render_html(meta: dict[str, Any], rows: list[dict[str, Any]]) -> str:
    esc = html_escape
    parts: list[str] = [
        "<!doctype html>",
        '<html lang="en"><head><meta charset="utf-8"/>',
        "<title>Cookiy CLI · response audit</title>",
        f"<style>{HTML_STYLE}</style>",
        "</head><body><div class='page'>",
        '<header class="doc">',
        "<h1>Cookiy CLI · response audit</h1>",
        '<p>Generated '
        f'<code>{esc(meta["generated_at"])}</code> · CLI <code>{esc(meta["cli_version"])}</code> · server <code>{esc(meta["server_url"])}</code>.</p>',
        '<p>Read study (data-rich): <code>'
        f'{esc(meta["study_id"])}</code> · write study (scratch): <code>{esc(meta["write_study_id"])}</code> · '
        f'interview <code>{esc(meta["interview_id"])}</code> · survey <code>{esc(meta["survey_id"])}</code>'
        + (f' · dynamic survey <code>{esc(meta["survey_id_dynamic"])}</code>' if meta.get("survey_id_dynamic") else "")
        + ".</p>",
        '<p>Scope: all <code>cookiy.sh</code> commands except <code>recruit</code>. '
        'Every card shows the CLI invocation, the response shape tree, and a collapsible raw sample of the first JSON value.</p>',
        '<div class="legend">',
        '<span class="swatch ok">OK — command returned structured JSON</span>',
        '<span class="swatch fail">FAIL — non-zero exit or MCP error envelope</span>',
        '<span class="swatch skip">SKIP — gated by env var or unimplemented in CLI</span>',
        "</div>",
        "</header>",
    ]

    by_cat: dict[str, list[dict[str, Any]]] = {cat: [] for cat, _ in CATEGORIES}
    by_cat["Other"] = []
    for r in rows:
        by_cat.setdefault(category_of(r["name"]), []).append(r)

    cat_order = [c for c, _ in CATEGORIES] + ["Other"]
    for cat in cat_order:
        group = by_cat.get(cat) or []
        if not group:
            continue
        parts.append(
            '<div class="divider">'
            f'<div class="title">{esc(cat)}</div>'
            f'<div class="sub">{len(group)} command{"s" if len(group) != 1 else ""}</div>'
            "</div>"
        )
        for r in group:
            ec = r.get("exit_code", 0)
            kind = r.get("response_kind", "non_json")
            jn = r.get("json_value_count", 0)
            is_skip = "(not run" in (r.get("shape_compact", "") or "")
            is_err = ec != 0 and not is_skip
            section_cls = "tool" + (" fail" if is_err else "") + (" skip" if is_skip else "")
            badge_cls = "skip" if is_skip else ("fail" if is_err else "ok")
            badge_txt = "SKIP" if is_skip else ("FAIL" if is_err else "OK")
            tool_id = tool_id_from_cmd(r.get("cmd") or [])
            summary_line = (
                f"exit {ec}"
                + (f" · {jn} JSON value(s)" if kind == "json" else " · non-JSON")
            )

            parts.append(f'<section class="{section_cls}">')
            parts.append("<header>")
            parts.append("<h2>")
            parts.append(f'<span class="cli">{esc(r["name"])}</span>')
            if tool_id:
                parts.append(f'<span class="tool-id">→ {esc(tool_id)}</span>')
            parts.append(f'<span class="badge {badge_cls}">{badge_txt}</span>')
            parts.append("</h2>")
            parts.append(f'<div class="summary">{esc(summary_line)}</div>')
            parts.append("</header>")
            parts.append('<div class="body">')
            cmd = r.get("cmd") or []
            if cmd:
                cmd_str = "cookiy.sh " + " ".join(cmd)
                parts.append(f'<div class="cmd">{esc(cmd_str)}</div>')
            shape = (r.get("shape_compact", "") or "").rstrip("\n")
            raw = r.get("raw_sample", "") or ""
            # Layout: shape tree on the left, raw sample on the right when both are present
            if shape and raw and not is_skip:
                parts.append('<div class="panes">')
                parts.append('<div class="pane"><h4>Shape tree</h4>'
                             f'<pre class="shape">{esc(shape)}</pre></div>')
                parts.append('<div class="pane"><h4>Raw response</h4>'
                             f'<pre class="raw">{esc(raw)}</pre></div>')
                parts.append("</div>")
            elif shape:
                parts.append('<div class="panes"><div class="pane single"><h4>Shape tree</h4>'
                             f'<pre class="shape">{esc(shape)}</pre></div></div>')
            parts.append("</div></section>")

    parts.append(
        '<footer class="doc">'
        f'{len([r for r in rows if r.get("exit_code") == 0 and "(not run" not in (r.get("shape_compact") or "")])} OK · '
        f'{len([r for r in rows if r.get("exit_code", 0) != 0 and "(not run" not in (r.get("shape_compact") or "")])} FAIL · '
        f'{len([r for r in rows if "(not run" in (r.get("shape_compact") or "")])} SKIP · '
        'source: <code>cli_audit_shapes.py</code>'
        "</footer>"
    )
    parts.append("</div></body></html>")
    return "\n".join(parts)


def render_markdown(meta: dict[str, Any], rows: list[dict[str, Any]]) -> str:
    lines: list[str] = [
        "# Cookiy CLI — response structure audit",
        "",
        f"- Generated: `{meta['generated_at']}`",
        f"- CLI: `{meta['cli_version']}` · Server: `{meta['server_url']}`",
        f"- Read study (data-rich): `{meta['study_id']}`",
        f"- Write study (scratch): `{meta['write_study_id']}`",
        f"- Interview / Survey: `{meta['interview_id']}` / `{meta['survey_id']}`",
        f"- Dynamic survey used after `quant create`: `{meta.get('survey_id_dynamic', '(n/a)')}`",
        "- Scope: **all cookiy.sh commands** except **`recruit`** (same order as implementation allows).",
        "",
        "Expand each command to see the **field-type tree** (placeholders only).",
        "",
    ]
    for r in rows:
        name = r["name"]
        ec = r["exit_code"]
        jn = r["json_value_count"]
        kind = r["response_kind"]
        summ = f"`{name}` · exit {ec}"
        if kind == "json":
            summ += f" · {jn} JSON value(s)"
        else:
            summ += " · non-JSON (help text or MCP error)"
        block = r["shape_compact"].rstrip("\n")
        lines.append("<details>")
        lines.append(f"<summary>{summ}</summary>")
        lines.append("")
        lines.append("```text")
        lines.append(block)
        lines.append("```")
        lines.append("")
        lines.append("</details>")
        lines.append("")
    lines.extend(
        [
            "---",
            "",
            "**Notes:** Types are placeholders. Arrays show the **first element** shape; depth/key count may truncate. "
            "`billing transactions --survey-id` may fail if the API rejects numeric `survey_id`. "
            "Set `CLI_AUDIT_SKIP_CHECKOUT=1` to skip wallet checkout; `CLI_AUDIT_SKIP_SAVE_TOKEN=1` to skip token probe.",
            "",
        ]
    )
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    default_md = os.path.join(repo, "cli-response-structure-audit.md")
    md_path = os.environ.get("CLI_AUDIT_OUT", default_md)
    html_path = os.environ.get(
        "CLI_AUDIT_HTML_OUT",
        md_path[:-3] + ".html" if md_path.endswith(".md") else md_path + ".html",
    )

    cli = os.environ.get("CLI", os.path.join(repo, "scripts", "cookiy.sh"))
    # Default to s (prod), which runs preview/20260420 branch. Override with
    # COOKIY_SERVER_URL=https://preview-api.cookiy.ai to audit the preview env.
    server = os.environ.get("COOKIY_SERVER_URL", "https://s-api.cookiy.ai")
    os.environ["COOKIY_SERVER_URL"] = server

    # Split IDs: STUDY_ID is the read-only target (has completed interviews + report).
    # WRITE_STUDY_ID is the scratch target for mutation tests (guide update, etc.).
    study_id = os.environ.get("STUDY_ID", "019c51ab-cb2b-7094-a59f-e9d12e18ffc9")
    write_study_id = os.environ.get("WRITE_STUDY_ID", "019d950f-2493-712e-bf9e-f3526a4effca")
    interview_id = os.environ.get("INTERVIEW_ID", "019d0506-2a2a-76aa-bdf2-e0c25e7a51b8")
    survey_id = os.environ.get("SURVEY_ID", "878381")

    skip_checkout = os.environ.get("CLI_AUDIT_SKIP_CHECKOUT", "1") == "1"
    skip_save_token = os.environ.get("CLI_AUDIT_SKIP_SAVE_TOKEN", "1") == "1"
    skip_synthetic = os.environ.get("CLI_AUDIT_SKIP_SYNTHETIC", "0") == "1"
    skip_report_generate = os.environ.get("CLI_AUDIT_SKIP_REPORT_GENERATE", "0") == "1"
    report_wait_ms = os.environ.get("CLI_AUDIT_REPORT_WAIT_MS", "8000")

    ver_cmd = ["node", cli, "--version"] if cli.endswith(".js") else ["bash", cli, "--version"]
    ver_p = subprocess.run(ver_cmd, capture_output=True, text=True)
    cli_version = (ver_p.stdout or ver_p.stderr or "").strip().split("\n")[0] or "unknown"

    rows: list[dict[str, Any]] = []
    survey_id_dynamic: str | None = None

    def add(name: str, args: list[str]) -> None:
        ec, text = run_cli(cli, args)
        rows.append(row_from_text(name, ec, text, cmd=args))

    # --- no credentials: usage, help, version ---
    add("usage (no args)", [])
    add("-h / --help", ["-h"])
    add("--version", ["--version"])
    add("help", ["help"])
    add("help commands (argv ignored by CLI; same body as help)", ["help", "commands"])

    # save-token (optional skip: still hits API to validate)
    if skip_save_token:
        rows.append(
            {
                "name": "save-token (skipped — CLI_AUDIT_SKIP_SAVE_TOKEN=1)",
                "cmd": [],
                "exit_code": 0,
                "response_kind": "non_json",
                "json_value_count": 0,
                "shape_compact": "(not run)\n",
                "raw_sample": "(not run)",
            }
        )
    else:
        add("save-token <invalid>", ["save-token", "not-a-valid-jwt"])

    # --- credentials required from here ---
    add("study list --limit 3", ["study", "list", "--limit", "3"])

    ec_list, text_list = run_cli(cli, ["study", "list", "--limit", "1"])
    rows.append(
        row_from_text(
            "study list --limit 1 (seed cursor)",
            ec_list,
            text_list,
            cmd=["study", "list", "--limit", "1"],
        )
    )
    d0 = first_dict(text_list)
    next_c = d0.get("next_cursor") if d0 else None
    if next_c:
        ec_c, text_c = run_cli(
            cli, ["study", "list", "--limit", "1", "--cursor", str(next_c)]
        )
        rows.append(
            row_from_text(
                "study list --limit 1 --cursor <from prior>",
                ec_c,
                text_c,
                cmd=["study", "list", "--limit", "1", "--cursor", str(next_c)],
            )
        )

    ts = int(time.time())
    add(
        "study create --query (no --wait)",
        ["study", "create", "--query", f"CLI audit scratch study {ts}"],
    )

    add("study status --study-id", ["study", "status", "--study-id", study_id])

    add(
        "study upload --image-url",
        [
            "study",
            "upload",
            "--content-type",
            "image/png",
            "--image-url",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
        ],
    )

    # Guide get/update target the WRITE scratch study so the audit does not
    # clobber a real study's guide revision.
    ec_g, text_g = run_cli(cli, ["study", "guide", "get", "--study-id", write_study_id])
    rows.append(
        row_from_text(
            "study guide get --study-id (scratch)",
            ec_g,
            text_g,
            cmd=["study", "guide", "get", "--study-id", write_study_id],
        )
    )
    rev = extract_guide_revision(text_g)
    if rev:
        idem = str(uuid.uuid4())
        patch = json.dumps(
            {"research_overview.research_objective": f"CLI audit bump {ts}"}
        )
        add(
            "study guide update --json (minimal patch, scratch)",
            [
                "study",
                "guide",
                "update",
                "--study-id",
                write_study_id,
                "--base-revision",
                rev,
                "--idempotency-key",
                idem,
                "--json",
                patch,
                "--change-message",
                "cli_audit_shapes",
            ],
        )
    else:
        rows.append(
            {
                "name": "study guide update (skipped — no revision from guide get)",
                "cmd": [],
                "exit_code": 0,
                "response_kind": "non_json",
                "json_value_count": 0,
                "shape_compact": "(not run)\n",
                "raw_sample": "(not run)",
            }
        )

    ec_il, text_il = run_cli(cli, ["study", "interview", "list", "--study-id", study_id])
    rows.append(
        row_from_text(
            "study interview list --study-id",
            ec_il,
            text_il,
            cmd=["study", "interview", "list", "--study-id", study_id],
        )
    )
    il = first_dict(text_il)
    if isinstance(il, dict) and il.get("next_cursor"):
        ec_i2, text_i2 = run_cli(
            cli,
            [
                "study",
                "interview",
                "list",
                "--study-id",
                study_id,
                "--cursor",
                str(il["next_cursor"]),
            ],
        )
        rows.append(
            row_from_text(
                "study interview list --study-id --cursor <from prior>",
                ec_i2,
                text_i2,
                cmd=["study", "interview", "list", "--study-id", study_id, "--cursor", str(il["next_cursor"])],
            )
        )

    add(
        "study interview playback url --study-id (no interview-id)",
        ["study", "interview", "playback", "url", "--study-id", study_id],
    )
    add(
        "study interview playback url --study-id --interview-id",
        [
            "study",
            "interview",
            "playback",
            "url",
            "--study-id",
            study_id,
            "--interview-id",
            interview_id,
        ],
    )
    add(
        "study interview playback content --study-id (no interview-id)",
        ["study", "interview", "playback", "content", "--study-id", study_id],
    )
    add(
        "study interview playback content --study-id --interview-id",
        [
            "study",
            "interview",
            "playback",
            "content",
            "--study-id",
            study_id,
            "--interview-id",
            interview_id,
        ],
    )

    if skip_synthetic:
        rows.append(
            {
                "name": "study run-synthetic-user start (skipped — CLI_AUDIT_SKIP_SYNTHETIC=1)",
                "cmd": [],
                "exit_code": 0,
                "response_kind": "non_json",
                "json_value_count": 0,
                "shape_compact": "(not run — paid op)\n",
                "raw_sample": "(not run — paid op)",
            }
        )
    else:
        # NOTE: --plain-text hits a shell bug (line 772: `local` outside a
        # function) in cookiy.sh v1.21.0; omit it here.
        add(
            "study run-synthetic-user start (no --wait, scratch)",
            [
                "study",
                "run-synthetic-user",
                "start",
                "--study-id",
                write_study_id,
                "--persona-count",
                "1",
            ],
        )

    if skip_report_generate:
        rows.append(
            {
                "name": "study report generate (skipped — CLI_AUDIT_SKIP_REPORT_GENERATE=1)",
                "cmd": [],
                "exit_code": 0,
                "response_kind": "non_json",
                "json_value_count": 0,
                "shape_compact": "(not run — paid op)\n",
                "raw_sample": "(not run — paid op)",
            }
        )
    else:
        add(
            "study report generate --skip-synthetic-interview (no --wait, scratch)",
            [
                "study",
                "report",
                "generate",
                "--study-id",
                write_study_id,
                "--skip-synthetic-interview",
            ],
        )

    add("study report content --study-id", ["study", "report", "content", "--study-id", study_id])
    add(
        "study report content --study-id --wait true --timeout-ms",
        [
            "study",
            "report",
            "content",
            "--study-id",
            study_id,
            "--wait",
            "true",
            "--timeout-ms",
            "8000",
        ],
    )
    add("study report link --study-id", ["study", "report", "link", "--study-id", study_id])
    add(
        "study report wait --study-id",
        ["study", "report", "wait", "--study-id", study_id, "--timeout-ms", report_wait_ms],
    )

    add("quant list", ["quant", "list"])

    create_payload = json.dumps(
        {
            "survey_title": f"CLI audit survey {ts}",
            "languages": ["en"],
            "groups": [
                {
                    "title": "G1",
                    "questions": [
                        {
                            "code": "Q1",
                            "type": "list_radio",
                            "text": "Pick one",
                            "options": [
                                {"code": "A1", "label": "A"},
                                {"code": "A2", "label": "B"},
                            ],
                        }
                    ],
                }
            ],
        }
    )
    ec_qc, text_qc = run_cli(cli, ["quant", "create", "--json", create_payload])
    rows.append(
        row_from_text(
            "quant create --json",
            ec_qc,
            text_qc,
            cmd=["quant", "create", "--json", "(payload)"],
        )
    )
    survey_id_dynamic = extract_survey_id(text_qc) or survey_id

    sid = survey_id_dynamic
    add("quant get --survey-id", ["quant", "get", "--survey-id", sid])
    # MCP expects survey.title (not survey_title); otherwise tool rejects patch as empty
    upd = json.dumps({"survey": {"title": f"CLI audit survey {ts} (patched)"}})
    add(
        "quant update --json",
        ["quant", "update", "--survey-id", sid, "--json", upd],
    )
    add("quant status --survey-id", ["quant", "status", "--survey-id", sid])
    add("quant report --survey-id", ["quant", "report", "--survey-id", sid])
    # For raw-response we use a different survey id (939797) that has real
    # responses in the backend, so the captured shape shows actual answer
    # rows rather than an empty array.
    raw_response_survey_id = os.environ.get("RAW_RESPONSE_SURVEY_ID", "939797")
    add(
        "quant raw-response --survey-id",
        ["quant", "raw-response", "--survey-id", raw_response_survey_id],
    )
    add(
        "quant raw-response --survey-id --include-incomplete",
        [
            "quant",
            "raw-response",
            "--survey-id",
            raw_response_survey_id,
            "--include-incomplete",
        ],
    )
    add("billing balance", ["billing", "balance"])

    if skip_checkout:
        rows.append(
            {
                "name": "billing checkout (skipped — CLI_AUDIT_SKIP_CHECKOUT=1)",
                "cmd": [],
                "exit_code": 0,
                "response_kind": "non_json",
                "json_value_count": 0,
                "shape_compact": "(not run — set CLI_AUDIT_SKIP_CHECKOUT=0 to exercise)\n",
                "raw_sample": "(not run)",
            }
        )
    else:
        add(
            "billing checkout --amount-usd-cents",
            ["billing", "checkout", "--amount-usd-cents", "1000"],
        )

    add("billing price-table", ["billing", "price-table"])
    add("billing transactions --limit 5", ["billing", "transactions", "--limit", "5"])
    add(
        "billing transactions --study-id",
        ["billing", "transactions", "--limit", "5", "--study-id", study_id],
    )
    add(
        "billing transactions --survey-id",
        ["billing", "transactions", "--limit", "5", "--survey-id", survey_id],
    )

    meta = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "cli_version": cli_version,
        "server_url": server,
        "study_id": study_id,
        "write_study_id": write_study_id,
        "interview_id": interview_id,
        "survey_id": survey_id,
        "survey_id_dynamic": survey_id_dynamic or "",
    }

    with open(md_path, "w", encoding="utf-8") as f:
        f.write(render_markdown(meta, rows))

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(render_html(meta, rows))

    print(md_path, file=sys.stderr)
    print(html_path, file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
