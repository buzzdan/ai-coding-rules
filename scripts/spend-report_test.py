#!/usr/bin/env python3
"""spend-report_test.py — the report reads both trace shapes.

Older Claude Code traces carry a stream_event message_start per main-thread
call; newer ones (2.1.259) carry the usage on the assistant event instead.
The report must count main-thread calls and context either way.

    python3 scripts/spend-report_test.py
"""
import importlib
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
spend = importlib.import_module("spend-report")


_ids = iter(range(1, 10_000))


def assistant(usage, parent=None, tool=None, msg_id=None):
    content = [{"type": "tool_use", "id": "t1", "name": tool, "input": {"command": "ls"}}] if tool else [{"type": "text", "text": "hi"}]
    return {"type": "assistant", "parent_tool_use_id": parent, "message": {"id": msg_id or f"msg_{next(_ids)}", "usage": usage, "content": content}}


def write_trace(events):
    f = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    for e in events:
        f.write(json.dumps(e) + "\n")
    f.close()
    return f.name


U1 = {"input_tokens": 2, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 40000, "output_tokens": 5}
U2 = {"input_tokens": 2, "cache_read_input_tokens": 40000, "cache_creation_input_tokens": 3000, "output_tokens": 5}
RESULT = {"type": "result", "total_cost_usd": 0.1, "modelUsage": {}}


class MainThreadContext(unittest.TestCase):
    def test_from_assistant_usage_when_the_trace_has_no_stream_events(self):
        r = spend.analyze(write_trace([{"type": "system", "subtype": "init"}, assistant(U1, tool="Bash"), assistant(U2), RESULT]))
        self.assertEqual(r["calls"], 2)
        self.assertEqual(r["mean_ctx"], (40002 + 43002) // 2)
        self.assertEqual(r["max_ctx"], 43002)

    def test_subagent_usage_is_not_a_main_thread_call(self):
        r = spend.analyze(write_trace([assistant(U1, tool="Bash"), assistant(U2, parent="tool_1"), RESULT]))
        self.assertEqual(r["calls"], 1)

    def test_one_api_call_split_over_two_assistant_events_counts_once(self):
        r = spend.analyze(write_trace([assistant(U1, msg_id="msg_a"), assistant(U1, tool="Bash", msg_id="msg_a"), assistant(U2, msg_id="msg_b"), RESULT]))
        self.assertEqual(r["calls"], 2)

    def test_stream_events_still_win_when_present(self):
        start = {"type": "stream_event", "parent_tool_use_id": None, "event": {"type": "message_start", "message": {"usage": U1}}}
        r = spend.analyze(write_trace([start, assistant(U1, tool="Bash"), RESULT]))
        self.assertEqual(r["calls"], 1)


if __name__ == "__main__":
    unittest.main()
