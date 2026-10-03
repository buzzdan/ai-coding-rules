#!/usr/bin/env python3
"""parent-edits_test.py — the trace check counts what the parent edited and what the workers did.

    python3 scripts/parent-edits_test.py
"""
import importlib
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
pe = importlib.import_module("parent-edits")

WORKER = "go-linter-driven-development:move-implementer"


def tool_use(name, inp, tid, parent=None, mid=None):
    return {"type": "assistant", "parent_tool_use_id": parent,
            "message": {"id": mid or f"msg_{tid}", "content": [{"type": "tool_use", "id": tid, "name": name, "input": inp}]}}


def tool_result(tid, text, parent=None, is_error=False):
    block = {"type": "tool_result", "tool_use_id": tid, "content": text}
    if is_error:
        block["is_error"] = True
    return {"type": "user", "parent_tool_use_id": parent, "message": {"content": [block]}}


def write_trace(events):
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    for e in events:
        f.write(json.dumps(e) + "\n")
    f.close()
    return f.name


RECEIPT = "STATUS: GREEN\nMOVES: 1 — 1 GREEN · 0 DEFERRED · 0 SKIPPED\nCOMMIT: abc1234 Extract Leaf Type: picker\nFILES: a.go | 2 +-\nRUNS: move-1 2\nTESTS: ok   LINT: 0 issues\nBASE-RED: none\nREPORT: /tmp/r"
SLICE = "== slice 1 (wave 1) 1 file, 1 move\nMOVE 1: Extract Leaf Type — R3 — a.go:10\nFILES: a.go\nPKGS: .\nRULE: /r/R3.md\nBASE: abc\nREPORT: /tmp/r"


class ParentEdits(unittest.TestCase):
    def test_counts_parent_edits_spawns_per_message_and_runs_per_move(self):
        events = [
            tool_use("Edit", {"file_path": "x.go"}, "e1"),
            tool_use("Bash", {"command": "bash s/ldd-slices.sh slices.tsv"}, "b0"),
            tool_result("b0", "ldd-slices: 2 lines → 2 slices in 2 waves (0 large, 0 duplicate lines dropped)\n-- wave 1\n== slice 1 (wave 1) 1 file, 1 move\n-- wave 2\n== slice 2 (wave 2) 1 file, 1 move"),
            tool_use("Agent", {"subagent_type": WORKER, "prompt": SLICE}, "a1", mid="m1"),
            tool_use("Agent", {"subagent_type": WORKER, "prompt": SLICE.replace("a.go:10", "b.go:20")}, "a2", mid="m1"),
            tool_use("Bash", {"command": "bash /p/scripts/ldd-attempt.sh /tmp/r move-1 test -- go test ./..."}, "w1", parent="a1"),
            tool_use("Bash", {"command": "bash /p/scripts/ldd-attempt.sh /tmp/r move-1 lint -- golangci-lint run"}, "w2", parent="a1"),
            tool_use("Bash", {"command": "bash /p/scripts/ldd-attempt.sh /tmp/r 1 build -- go build ./..."}, "w3", parent="a1"),
            tool_use("Bash", {"command": "bash /p/scripts/ldd-attempt.sh /tmp/r move-2 test -- go test ./..."}, "w4", parent="a1"),
            tool_use("Bash", {"command": "git status"}, "w5", parent="a2"),
            tool_result("a1", RECEIPT),
            tool_result("a2", RECEIPT),
            {"type": "result", "total_cost_usd": 0.1},
        ]
        line = pe.check(write_trace(events), case="case-x", run="run-1")
        self.assertEqual(line, "case-x run-1: parent Edit 1 Write 0 | move-implementer spawns 2 in 1 message(s), waves 2, "
                               "max runs per move 3, direct verification runs 0 (denied 0), re-spawns per move max 0, "
                               "receipts over 15 lines 0, GREEN without COMMIT 0")

    def test_counts_direct_runs_denied_and_not_and_re_spawns_of_one_move(self):
        events = [
            tool_use("Agent", {"subagent_type": WORKER, "prompt": SLICE}, "a1", mid="m1"),
            tool_use("Bash", {"command": "go test ./..."}, "w1", parent="a1"),
            tool_result("w1", "PreToolUse:Bash hook error: use ldd-attempt.sh for test, lint and build runs", parent="a1", is_error=True),
            tool_use("Bash", {"command": "cd pkg && golangci-lint run ./..."}, "w2", parent="a1"),
            tool_result("w2", "0 issues.", parent="a1"),
            tool_result("a1", RECEIPT.replace("STATUS: GREEN", "STATUS: DEFERRED")),
            tool_use("Agent", {"subagent_type": WORKER, "prompt": SLICE + "\nDEFERRED-NEEDS re-spawn"}, "a2", mid="m2"),
            tool_result("a2", RECEIPT),
            tool_use("Agent", {"subagent_type": WORKER, "prompt": SLICE}, "a3", mid="m3"),
            tool_result("a3", RECEIPT),
            {"type": "result"},
        ]
        line = pe.check(write_trace(events), case="c", run="run-2")
        self.assertIn("spawns 3 in 3 message(s), waves 0", line)
        self.assertIn("direct verification runs 1 (denied 1)", line)
        self.assertIn("re-spawns per move max 2", line)

    def test_flags_a_green_receipt_without_a_commit_and_a_long_receipt(self):
        long_receipt = "\n".join(["STATUS: GREEN"] + [f"line {i}" for i in range(20)])
        events = [
            tool_use("Agent", {"subagent_type": WORKER}, "a1"),
            tool_result("a1", long_receipt),
            {"type": "result"},
        ]
        line = pe.check(write_trace(events), case="c", run="run-2")
        self.assertIn("receipts over 15 lines 1", line)
        self.assertIn("GREEN without COMMIT 1", line)


if __name__ == "__main__":
    unittest.main()
