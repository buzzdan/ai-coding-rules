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


def tool_use(name, inp, tid, parent=None):
    return {"type": "assistant", "parent_tool_use_id": parent, "message": {"content": [{"type": "tool_use", "id": tid, "name": name, "input": inp}]}}


def tool_result(tid, text, parent=None):
    return {"type": "user", "parent_tool_use_id": parent, "message": {"content": [{"type": "tool_result", "tool_use_id": tid, "content": text}]}}


def write_trace(events):
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    for e in events:
        f.write(json.dumps(e) + "\n")
    f.close()
    return f.name


RECEIPT = "STATUS: GREEN\nMOVE: Extract Leaf Type — R3\nCOMMIT: abc1234 Extract Leaf Type: picker\nFILES: a.go | 2 +-\nTESTS: ok\nLINT: 0 issues\nREPORT: /tmp/r"


class ParentEdits(unittest.TestCase):
    def test_counts_parent_edits_and_worker_shape(self):
        events = [
            tool_use("Edit", {"file_path": "x.go"}, "e1"),
            tool_use("Agent", {"subagent_type": "go-linter-driven-development:move-implementer", "prompt": "MOVE: …"}, "a1"),
            tool_use("Edit", {"file_path": "a.go"}, "e2", parent="a1"),
            tool_use("Edit", {"file_path": "b.go"}, "e3", parent="a1"),
            tool_result("a1", RECEIPT),
            {"type": "result", "total_cost_usd": 0.1},
        ]
        line = pe.check(write_trace(events), case="case-x", run="run-1")
        self.assertEqual(line, "case-x run-1: parent Edit 1 Write 0 | move-implementer spawns 1, max files per worker 2, receipts over 15 lines 0, GREEN without COMMIT 0")

    def test_flags_a_green_receipt_without_a_commit_and_a_long_receipt(self):
        long_receipt = "\n".join(["STATUS: GREEN"] + [f"line {i}" for i in range(20)])
        events = [
            tool_use("Agent", {"subagent_type": "go-linter-driven-development:move-implementer"}, "a1"),
            tool_result("a1", long_receipt),
            {"type": "result"},
        ]
        line = pe.check(write_trace(events), case="c", run="run-2")
        self.assertIn("receipts over 15 lines 1", line)
        self.assertIn("GREEN without COMMIT 1", line)


if __name__ == "__main__":
    unittest.main()
