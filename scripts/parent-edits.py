#!/usr/bin/env python3
"""parent-edits.py — did the parent edit, and what did the move implementers do?

Reads every trace.jsonl under a results or baseline directory and prints one line
per run:

  <case> <run>: parent Edit <n> Write <n> | move-implementer spawns <n>,
  max files per worker <n>, receipts over 15 lines <n>, GREEN without COMMIT <n>

"parent" is the main thread (events with no parent_tool_use_id). A worker is an
Agent call whose subagent_type ends in "move-implementer"; its files are the
distinct paths its Edit and Write calls name; its receipt is the Agent call's
tool_result. The expected line on a refactor run after stage S10 is
"parent Edit 0 Write 0" with every GREEN receipt carrying a COMMIT line.

    python3 scripts/parent-edits.py <dir>
"""
import glob
import json
import os
import sys

WORKER = "move-implementer"


def _text(block):
    content = block.get("content")
    if isinstance(content, list):
        content = "".join(x.get("text", "") for x in content if isinstance(x, dict))
    return content or ""


def check(trace_path, case="?", run="?"):
    parent_edits = {"Edit": 0, "Write": 0}
    workers = {}  # agent tool_use id -> set of files
    receipts = {}  # agent tool_use id -> receipt text
    for line in open(trace_path, encoding="utf-8", errors="ignore"):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        kind = ev.get("type")
        parent = ev.get("parent_tool_use_id")
        content = ev.get("message", {}).get("content") if isinstance(ev.get("message"), dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if kind == "assistant" and block.get("type") == "tool_use":
                name = block.get("name")
                inp = block.get("input", {})
                if parent is None and name in parent_edits:
                    parent_edits[name] += 1
                if name == "Agent" and str(inp.get("subagent_type", "")).endswith(WORKER):
                    workers.setdefault(block["id"], set())
                if parent in workers and name in ("Edit", "Write") and inp.get("file_path"):
                    workers[parent].add(inp["file_path"])
            elif kind == "user" and block.get("type") == "tool_result" and block.get("tool_use_id") in workers:
                receipts[block["tool_use_id"]] = _text(block)
    max_files = max((len(f) for f in workers.values()), default=0)
    long_receipts = sum(1 for r in receipts.values() if len([l for l in r.splitlines() if l.strip()]) > 15)
    green_no_commit = sum(1 for r in receipts.values() if "STATUS: GREEN" in r and "COMMIT:" not in r)
    return (f"{case} {run}: parent Edit {parent_edits['Edit']} Write {parent_edits['Write']} | "
            f"{WORKER} spawns {len(workers)}, max files per worker {max_files}, "
            f"receipts over 15 lines {long_receipts}, GREEN without COMMIT {green_no_commit}")


def main(root):
    for path in sorted(glob.glob(os.path.join(root, "**", "trace.jsonl"), recursive=True)):
        parts = os.path.relpath(path, root).split(os.sep)
        run = parts[-2] if len(parts) >= 2 else "?"
        case = parts[-3] if len(parts) >= 3 else "?"
        print(check(path, case=case, run=run))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1])
