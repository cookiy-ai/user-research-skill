#!/usr/bin/env python3
"""
Split a plain-text transcript into rows for first-pass qualitative coding.

Usage:
  python3 scripts/transcript_to_codes.py input.txt -o coding_sheet.csv

Lines separated by blank lines become one "segment" each; otherwise each
non-empty line is its own segment. Adjust in-script if your transcript format
differs.

This script has no third-party dependencies.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


def segment_text(text: str) -> list[str]:
    normalized = text.replace("\r\n", "\n").strip()
    if not normalized:
        return []
    blocks = re.split(r"\n\s*\n", normalized)
    segments: list[str] = []
    for block in blocks:
        lines = [ln.strip() for ln in block.split("\n") if ln.strip()]
        if not lines:
            continue
        if len(lines) == 1:
            segments.append(lines[0])
        else:
            segments.append("\n".join(lines))
    return segments


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Path to a UTF-8 text file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("coding_sheet.csv"),
        help="Output CSV path (default: coding_sheet.csv)",
    )
    args = parser.parse_args()

    try:
        raw = args.input.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"Error reading input: {exc}", file=sys.stderr)
        return 1

    segments = segment_text(raw)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["segment_id", "text", "code_v1", "notes"])
        for idx, seg in enumerate(segments, start=1):
            writer.writerow([idx, seg, "", ""])

    print(f"Wrote {len(segments)} rows to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
