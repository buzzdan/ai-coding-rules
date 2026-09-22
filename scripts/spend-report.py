#!/usr/bin/env python3
"""spend-report.py — where the tokens of an eval run go.

Reads every trace.jsonl under a results or baseline directory (the layout the
evals runner writes: <tier>/<case>/run-N/trace.jsonl, or <case>/run-N/trace.jsonl)
and prints three tables:

  1. per run: billed tokens, cost, main-thread API calls, mean context per call,
     subagents spawned and the share of the bill they account for;
  2. per tier: billed tokens attributed to what filled the context — the fixed
     first-call context, plugin text (rules, skills, examples), repository work
     (source reads, greps, tests, edits), agent spawns, and the subagents' own
     calls;
  3. per agent kind: turns, tool calls and result tokens, so a hunter that reads
     one file per turn shows up as such.

The cost model is the one the API bills: every call re-sends the whole context,
so a token that enters the context at call k is billed (calls - k) more times.
Table 2 charges each category exactly that. Token counts for the attribution are
estimated as UTF-8 length / 4; the "unattributed" line is the difference to the
context sizes the API reported (prior-turn thinking carried inside tool loops,
plus estimate error). The per-run totals in table 1 are the API's own numbers.

This is the reference implementation of the spend section of
docs/token-budget.md; the runner in buzzdan/ldd-evals is where the same report
belongs once the design lands (ldd-eval spend, planned).

    python3 scripts/spend-report.py <dir> [--markdown]
    zstd -dc baselines/go-2.11.0-c78b55f/traces.tar.zst | tar -xf - -C /tmp/t
    python3 scripts/spend-report.py /tmp/t --markdown
"""
import argparse
import collections
import glob
import json
import os
import re
import statistics
import sys


def toks(s):
    return len(s.encode("utf-8", "ignore")) // 4


def result_text(block):
    content = block.get("content")
    if isinstance(content, list):
        content = "".join(x.get("text", "") for x in content if isinstance(x, dict))
    return content or ""


PLUGIN_MARK = "linter-driven-development/"


def category(name, inp):
    """The bucket a tool call and its result fill in the context."""
    if name == "Skill":
        return "plugin: skill text injected"
    if name == "Read":
        path = inp.get("file_path", "")
        if "/rules/R" in path:
            return "plugin: rule files read by main thread"
        if PLUGIN_MARK in path:
            return "plugin: examples and skill docs read"
        return "repo: source reads"
    if name == "Bash":
        cmd = inp.get("command", "")
        if PLUGIN_MARK in cmd and re.search(r"\b(cat|sed|grep|head|tail)\b", cmd):
            return "plugin: rule and skill text via cat/sed"
        if re.search(r"go test|golangci|pytest|ruff|mypy|task (test|lint)|make (test|lint)", cmd):
            return "repo: test and lint output"
        if re.search(r"\bgrep\b|\brg\b|\bast-grep\b", cmd):
            return "repo: rule greps"
        if cmd.strip().startswith("git"):
            return "repo: git"
        return "repo: other shell"
    if name in ("Grep", "Glob"):
        return "repo: rule greps"
    if name in ("Agent", "Task"):
        return "agents: spawn prompt and returned report"
    if name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return "repo: edits"
    return "other tools"


FIXED = "fixed: first-call context (system prompt, tool defs, plugin descriptions, CLAUDE.md)"
SUBAGENTS = "subagents: all of their own calls"
UNATTRIBUTED = "unattributed: prior thinking in tool loops, estimate drift"


def analyze(trace_path):
    """One run: totals, main-thread context per call, attribution, agents."""
    pending = {}
    cumulative = collections.Counter()
    billed = collections.Counter()
    contexts = []
    agents = {}
    task_desc = {}
    total = cost = spawned = None
    for line in open(trace_path, encoding="utf-8", errors="ignore"):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        kind = ev.get("type")
        parent = ev.get("parent_tool_use_id")
        if kind == "system" and ev.get("subtype") == "task_started":
            task_desc[ev["tool_use_id"]] = (
                ev.get("description", ""),
                ev.get("subagent_type", "").split(":")[-1] or "general",
                toks(ev.get("prompt", "")),
            )
        elif kind == "stream_event" and ev["event"].get("type") == "message_start" and parent is None:
            usage = ev["event"]["message"]["usage"]
            ctx = usage["input_tokens"] + usage["cache_read_input_tokens"] + usage["cache_creation_input_tokens"]
            contexts.append(ctx)
            base = contexts[0]
            billed[FIXED] += base
            for cat, n in cumulative.items():
                billed[cat] += n
            billed[UNATTRIBUTED] += max(0, ctx - base - sum(cumulative.values()))
        elif kind == "assistant":
            agent = agents.setdefault(parent, dict(turns=0, tools=collections.Counter(), result_tokens=collections.Counter())) if parent else None
            if agent:
                agent["turns"] += 1
            for block in ev["message"].get("content", []):
                if block.get("type") == "tool_use":
                    pending[block["id"]] = (block["name"], block.get("input", {}), parent)
                    if agent:
                        agent["tools"][block["name"]] += 1
                    elif parent is None:
                        cumulative[category(block["name"], block.get("input", {}))] += toks(json.dumps(block.get("input", {})))
                elif block.get("type") == "text" and parent is None:
                    cumulative["model: own text output"] += toks(block["text"])
        elif kind == "user":
            content = ev["message"].get("content")
            if isinstance(content, str):
                if parent is None:
                    cumulative["user prompt"] += toks(content)
                continue
            for block in content or []:
                if block.get("type") == "tool_result":
                    name, inp, _ = pending.get(block.get("tool_use_id"), ("?", {}, None))
                    n = toks(result_text(block))
                    if parent:
                        agents.setdefault(parent, dict(turns=0, tools=collections.Counter(), result_tokens=collections.Counter()))["result_tokens"][name] += n
                    else:
                        cumulative[category(name, inp)] += n
                elif block.get("type") == "text" and parent is None:
                    text = block["text"]
                    cumulative["plugin: skill text injected" if "Base directory for this skill" in text else "user prompt"] += toks(text)
        elif kind == "result":
            usage = ev.get("modelUsage", {})
            total = sum(
                v.get("inputTokens", 0) + v.get("cacheReadInputTokens", 0) + v.get("cacheCreationInputTokens", 0) + v.get("outputTokens", 0)
                for v in usage.values()
            )
            cost = ev.get("total_cost_usd")
            spawned = ev.get("subagent_stats", {}).get("spawned", 0)
    main = sum(billed.values())
    billed[SUBAGENTS] = max(0, (total or 0) - main)
    agent_rows = []
    for tool_use_id, a in agents.items():
        desc, akind, prompt_toks = task_desc.get(tool_use_id, ("?", "general", 0))
        agent_rows.append(dict(kind=akind, desc=desc, prompt=prompt_toks, turns=a["turns"], tools=dict(a["tools"]), result_tokens=sum(a["result_tokens"].values())))
    return dict(total=total or 0, cost=cost or 0.0, calls=len(contexts), mean_ctx=(sum(contexts) // len(contexts)) if contexts else 0,
                max_ctx=max(contexts) if contexts else 0, spawned=spawned or 0, main=main, billed=billed, agents=agent_rows)


def find_runs(root):
    runs = []
    for path in sorted(glob.glob(os.path.join(root, "**", "trace.jsonl"), recursive=True)):
        rel = os.path.relpath(path, root).split(os.sep)
        # <tier>/<case>/run-N/trace.jsonl or <case>/run-N/trace.jsonl
        if len(rel) >= 4:
            tier, case, run = rel[-4], rel[-3], rel[-2]
        elif len(rel) == 3:
            tier, case, run = "all", rel[0], rel[1]
        else:
            continue
        runs.append((tier, case, run, path))
    return runs


def fmt_table(headers, rows, markdown):
    widths = [max(len(str(h)), *(len(str(r[i])) for r in rows)) for i, h in enumerate(headers)] if rows else [len(h) for h in headers]
    if markdown:
        out = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
        out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    else:
        out = ["  ".join(str(h).ljust(w) for h, w in zip(headers, widths))]
        out += ["  ".join(str(c).ljust(w) for c, w in zip(r, widths)) for r in rows]
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("root", help="results or unpacked-baseline directory")
    ap.add_argument("--markdown", action="store_true", help="emit markdown tables")
    args = ap.parse_args()
    runs = find_runs(args.root)
    if not runs:
        sys.exit(f"no trace.jsonl under {args.root}")

    per_run = []
    per_tier_billed = collections.defaultdict(collections.Counter)
    per_tier_runs = collections.Counter()
    agent_kinds = collections.defaultdict(list)
    for tier, case, run, path in runs:
        r = analyze(path)
        per_run.append((tier, case, run, r))
        per_tier_billed[tier].update(r["billed"])
        per_tier_runs[tier] += 1
        for a in r["agents"]:
            agent_kinds[a["kind"]].append(a)

    print("## Per run\n" if args.markdown else "== per run")
    rows = []
    for tier, case, run, r in per_run:
        sub_share = 100 * (r["total"] - r["main"]) / r["total"] if r["total"] else 0
        rows.append([tier, case, run, f"{r['total']/1e6:.2f}M", f"${r['cost']:.2f}", r["calls"], f"{r['mean_ctx']//1000}k", f"{r['max_ctx']//1000}k", r["spawned"], f"{sub_share:.0f}%"])
    print(fmt_table(["tier", "case", "run", "billed tokens", "cost", "main calls", "mean ctx", "max ctx", "agents", "agent share"], rows, args.markdown))

    for tier in sorted(per_tier_billed):
        b = per_tier_billed[tier]
        total = sum(b.values()) or 1
        print(f"\n## {tier} tier: {per_tier_runs[tier]} runs, {total:,} tokens billed\n" if args.markdown else f"\n== {tier} tier: {per_tier_runs[tier]} runs, {total:,} tokens billed")
        rows = [[f"{100*v/total:.1f}%", f"{v:,}", k] for k, v in b.most_common()]
        print(fmt_table(["share", "tokens", "what filled the context"], rows, args.markdown))

    print("\n## Per agent kind\n" if args.markdown else "\n== per agent kind")
    rows = []
    for kind, items in sorted(agent_kinds.items(), key=lambda kv: -len(kv[1])):
        turns = [a["turns"] for a in items]
        reads = [a["tools"].get("Read", 0) for a in items]
        prompts = [a["prompt"] for a in items]
        results = [a["result_tokens"] for a in items]
        rows.append([kind, len(items), int(statistics.median(turns)), max(turns), int(statistics.median(reads)), int(statistics.median(prompts)), int(statistics.median(results))])
    print(fmt_table(["agent", "n", "median turns", "max turns", "median Read calls", "median prompt tokens", "median result tokens"], rows, args.markdown))


if __name__ == "__main__":
    main()
