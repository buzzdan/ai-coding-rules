#!/usr/bin/env python3
"""parent-edits.py — did the parent edit, and what did the move implementers do?

Reads every trace.jsonl under a results or baseline directory and prints one line
per run:

  <case> <run>: parent Edit <n> Write <n> | move-implementer spawns <n> in <m> message(s),
  waves <w>, max runs per move <n>, direct verification runs <n> (denied <n>),
  re-spawns per move max <n>, receipts over 15 lines <n>, GREEN without COMMIT <n>

"parent" is the main thread (events with no parent_tool_use_id); its Edit and Write
calls are counted except the refactoring skill's own table files (slices.tsv,
slices.log, verdicts-<n>.txt). A worker is an
Agent call whose subagent_type ends in "move-implementer"; its receipt is the Agent
call's tool_result. Spawns "in <m> message(s)" counts the distinct message ids of the
parent's assistant events that carry a worker spawn: several spawns in one message
share one id. "waves" counts the "-- wave <n>" lines the slicing script printed in the
parent's Bash results; a parent that spawns a wave in one message has at most as
many messages as waves. "max runs per move" reads the worker's Bash commands that go
through ldd-attempt.sh (the report path, then move-<n> or <n>) and counts per move; a
call the wrapper refused ("BOUND:") or the hook denied is not a run.
"direct verification runs" are the worker's Bash commands that run a test, lint,
build or vet form without the wrapper and were not denied by the hook; the denied
attempts are counted beside them. "re-spawns per move" counts how many spawn prompts
after the first carry the same "MOVE n: <move> — R<n> — <anchor>" line. The expected
line on a refactor run is "parent Edit 0 Write 0", "direct verification runs 0", max
runs per move at most 3, re-spawns at most 1, and every GREEN receipt with a COMMIT
line.

    python3 scripts/parent-edits.py <dir>
"""
import glob
import json
import os
import re
import sys

WORKER = "move-implementer"
WRAPPER = "ldd-attempt.sh"
WRAPPER_RUN = re.compile(r"ldd-attempt\.sh\s+\S+\s+(?:move-)?(\d+)\s+(?:test|lint|build)\b")
VERIFY = re.compile(
    r"(?:^|[^A-Za-z0-9_./-])(?:go (?:test|vet|build)|golangci-lint|staticcheck|gofmt|pytest|"
    r"python[0-9.]* -m (?:pytest|unittest|ruff|mypy|pyright|flake8|pylint)|ruff (?:check|format)|"
    r"mypy|pyright|flake8|pylint|tox|nox|task (?:test|lint|build)|make (?:test|lint|build))(?:[^A-Za-z0-9_-]|$)")
MOVE_LINE = re.compile(r"^MOVE \d+: (.+)$", re.M)
WAVE_LINE = re.compile(r"^-- wave \d+$", re.M)
DENIED = re.compile(r"hook error|use ldd-attempt\.sh")
TABLE_FILE = re.compile(r"(^|/)(slices\.tsv|slices\.log|verdicts-\d+\.txt)$")  # the refactoring skill's own files, not source


def _text(block):
    content = block.get("content")
    if isinstance(content, list):
        content = "".join(x.get("text", "") for x in content if isinstance(x, dict))
    return content or ""


def _blocks(ev):
    message = ev.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict)]


def check(trace_path, case="?", run="?"):
    parent_edits = {"Edit": 0, "Write": 0}
    spawn_messages = set()
    workers = {}  # agent tool_use id -> {"runs": {move: n}, "direct": {bash id: command}}
    receipts = {}  # agent tool_use id -> receipt text
    move_lines = {}  # "MOVE n: …" text -> spawn prompts carrying it
    waves = 0
    parent_bash = set()
    direct_calls = {}  # bash tool_use id -> denied?
    wrapper_calls = {}  # bash tool_use id -> (worker id, move)
    for line in open(trace_path, encoding="utf-8", errors="ignore"):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        kind = ev.get("type")
        parent = ev.get("parent_tool_use_id")
        message = ev.get("message") if isinstance(ev.get("message"), dict) else {}
        for block in _blocks(ev):
            if kind == "assistant" and block.get("type") == "tool_use":
                name = block.get("name")
                inp = block.get("input", {})
                if parent is None and name in parent_edits and not TABLE_FILE.search(str(inp.get("file_path", ""))):
                    parent_edits[name] += 1
                if parent is None and name == "Bash":
                    parent_bash.add(block["id"])
                if name == "Agent" and str(inp.get("subagent_type", "")).endswith(WORKER):
                    workers.setdefault(block["id"], {"runs": {}})
                    spawn_messages.add(message.get("id") or block["id"])
                    for m in MOVE_LINE.findall(str(inp.get("prompt", ""))):
                        move_lines[m] = move_lines.get(m, 0) + 1
                if parent in workers and name == "Bash":
                    command = str(inp.get("command", ""))
                    if WRAPPER in command:
                        for move in WRAPPER_RUN.findall(command):
                            runs = workers[parent]["runs"]
                            runs[move] = runs.get(move, 0) + 1
                            wrapper_calls[block["id"]] = (parent, move)
                    elif VERIFY.search(command):
                        direct_calls[block["id"]] = False
            elif kind == "user" and block.get("type") == "tool_result":
                tid = block.get("tool_use_id")
                text = _text(block)
                if tid in workers:
                    receipts[tid] = text
                elif tid in parent_bash:
                    waves += len(WAVE_LINE.findall(text))
                elif tid in direct_calls and (block.get("is_error") or DENIED.search(text)):
                    direct_calls[tid] = True
                elif tid in wrapper_calls and ("BOUND:" in text or block.get("is_error") or DENIED.search(text)):
                    worker, move = wrapper_calls[tid]
                    workers[worker]["runs"][move] -= 1  # refused by the wrapper or denied by the hook: not a run
    max_runs = max((n for w in workers.values() for n in w["runs"].values()), default=0)
    denied = sum(1 for d in direct_calls.values() if d)
    direct = len(direct_calls) - denied
    respawns = max((n - 1 for n in move_lines.values()), default=0)
    long_receipts = sum(1 for r in receipts.values() if len([l for l in r.splitlines() if l.strip()]) > 15)
    green_no_commit = sum(1 for r in receipts.values() if "STATUS: GREEN" in r and "COMMIT:" not in r)
    return (f"{case} {run}: parent Edit {parent_edits['Edit']} Write {parent_edits['Write']} | "
            f"{WORKER} spawns {len(workers)} in {len(spawn_messages)} message(s), waves {waves}, "
            f"max runs per move {max_runs}, direct verification runs {direct} (denied {denied}), "
            f"re-spawns per move max {respawns}, "
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
