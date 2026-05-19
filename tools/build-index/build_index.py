#!/usr/bin/env python3
"""Rebuild decomk-conf-cswg proquint migration lookup files.

Reads tools/migrate-handles/mapping.tsv and writes root
numeric-proquint-xref.md. It also refreshes migrated TODO entries in
TODO/TODO.md while preserving the current priority order and explanatory text.
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

REPO = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
MAP = REPO / "tools/migrate-handles/mapping.tsv"
XREF = REPO / "numeric-proquint-xref.md"
TODO_INDEX = REPO / "TODO/TODO.md"


def load_rows() -> list[dict[str, str]]:
    with MAP.open(newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def write_xref(rows: list[dict[str, str]]) -> None:
    lines = [
        "# Numeric to proquint cross-reference",
        "",
        "This file is the human lookup table for the decomk-conf-cswg proquint ID migration.",
        "The machine-readable authority is `tools/migrate-handles/mapping.tsv`.",
        "",
        "| Old ID | New ID | Old path | New path | Title |",
        "| --- | --- | --- | --- | --- |",
    ]
    for r in rows:
        lines.append(
            f"| `{r['old_id']}` | `{r['new_id']}` | `{r['old_path']}` | `{r['new_path']}` | {escape_cell(r['title'])} |"
        )
    XREF.write_text("\n".join(lines) + "\n")


def escape_cell(text: str) -> str:
    return text.replace("|", "\\|")


def refresh_todo_index(rows: list[dict[str, str]]) -> None:
    todo_rows = {r["new_id"]: r for r in rows if r["kind"] == "TODO"}
    if not TODO_INDEX.exists():
        return
    out = []
    by_id = {r["old_id"]: r for r in rows if r["kind"] == "TODO"}
    by_id.update(todo_rows)
    by_path = {r["old_path"]: r for r in rows if r["kind"] == "TODO"}
    by_path.update({r["new_path"]: r for r in rows if r["kind"] == "TODO"})
    task_re = re.compile(r"^(?P<prefix>- \[[ xX]\] )(?P<label>(?:TODO-)?[A-Za-z0-9]+)(?: - .*?)? \(`(?P<path>TODO/[^`]+)`\)$")
    for line in TODO_INDEX.read_text().splitlines():
        m = task_re.match(line)
        if not m:
            out.append(line)
            continue
        label = m.group("label")
        row = by_id.get(label)
        if row is None and label.isdigit():
            row = by_id.get("TODO-" + label.zfill(3))
        if row is None:
            row = by_path.get(m.group("path"))
        if not row:
            out.append(line)
            continue
        out.append(f"{m.group('prefix')}{row['new_id']} - {row['title']} (`{row['new_path']}`)")
    TODO_INDEX.write_text("\n".join(out) + "\n")


def verify(rows: list[dict[str, str]]) -> None:
    missing = [r["new_path"].split("#", 1)[0] for r in rows if not (REPO / r["new_path"].split("#", 1)[0]).exists()]
    if missing:
        raise SystemExit("missing migrated paths:\n" + "\n".join(sorted(set(missing))))
    xref = XREF.read_text()
    for r in rows:
        if r["old_id"] not in xref or r["new_id"] not in xref:
            raise SystemExit(f"xref missing mapping for {r['old_id']} -> {r['new_id']}")


def main() -> None:
    rows = load_rows()
    write_xref(rows)
    refresh_todo_index(rows)
    verify(rows)
    print(f"build-index: wrote {XREF} with {len(rows)} rows", file=sys.stderr)


if __name__ == "__main__":
    main()
