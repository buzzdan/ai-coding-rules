package cli_test

import (
	"bytes"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/cli"
	"example.com/ldd-eval/internal/report"
)

func abs(t *testing.T, rel string) string {
	t.Helper()
	p, err := filepath.Abs(rel)
	if err != nil {
		t.Fatalf("abs %s: %v", rel, err)
	}
	return p
}

// useFakeClaude puts testdata/fake-claude.sh on PATH as `claude`, pointed at
// the synthetic two-tools trace, and returns the file the fake records its
// argv into.
func useFakeClaude(t *testing.T) string {
	t.Helper()
	bin := t.TempDir()
	if err := os.Symlink(abs(t, "../../testdata/fake-claude.sh"), filepath.Join(bin, "claude")); err != nil {
		t.Fatalf("symlink: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	t.Setenv("FAKE_CLAUDE_TRACE", abs(t, "../../testdata/trace-two-tools.jsonl"))
	argsOut := filepath.Join(t.TempDir(), "args.txt")
	t.Setenv("FAKE_CLAUDE_ARGS_OUT", argsOut)
	return argsOut
}

func run(t *testing.T, args ...string) (code int, stdout, stderr string) {
	t.Helper()
	var out, errBuf bytes.Buffer
	code = cli.Run(args, &out, &errBuf)
	return code, out.String(), errBuf.String()
}

func near(a, b float64) bool { return math.Abs(a-b) < 1e-9 }

// TestRun_EndToEnd is the one integration test: a fake claude on PATH, the
// tiny suite under testdata/suite, real scaffold/postcheck scripts, and the
// result.json / aggregate-result.json contents asserted.
func TestRun_EndToEnd(t *testing.T) {
	argsOut := useFakeClaude(t)
	suite := abs(t, "../../testdata/suite")
	out1 := filepath.Join(t.TempDir(), "out1")

	code, stdout, stderr := run(t, "run", "--out", out1, "--judge-model", "fake-judge", "--keep-temp", suite)
	if code != cli.ExitFail {
		t.Fatalf("whole suite exit = %d, want %d (minimal fails)\nstdout:\n%s\nstderr:\n%s", code, cli.ExitFail, stdout, stderr)
	}
	if !strings.Contains(stdout, "2 case(s)") || !strings.Contains(stderr, "threshold 1.00") {
		t.Errorf("progress/stderr = %q / %q", stdout, stderr)
	}
	assertWholeSuiteAggregate(t, out1)
	assertTwoToolsRun(t, out1, suite)
	assertAgentArgs(t, argsOut, suite)
	assertMinimalRun(t, out1)

	out2 := filepath.Join(t.TempDir(), "out2")
	code, _, stderr = run(t, "run", "--case", "two-*", "--model", "claude-haiku-4-5", "--out", out2, suite)
	if code != cli.ExitPass {
		t.Fatalf("--case two-* exit = %d, want 0: %s", code, stderr)
	}
	agg2 := readAggregate(t, out2)
	if len(agg2.Cases) != 1 || agg2.Cases[0].Name != "two-tools" || agg2.Aggregates.PassRate != 1 {
		t.Errorf("filtered aggregate = %+v", agg2)
	}
	res2 := agg2.Cases[0].Results[0]
	if res2.Model != "claude-haiku-4-5" || res2.ScaffoldDir != "" {
		t.Errorf("--model / no --keep-temp not honoured: %+v", res2)
	}

	out3 := filepath.Join(t.TempDir(), "out3")
	code, _, stderr = run(t, "run", "--case", "two-tools", "--runs", "3", "--max-cost-usd", "0.02", "--out", out3, suite)
	if code != cli.ExitBudget {
		t.Fatalf("budget exit = %d, want 2: %s", code, stderr)
	}
	agg3 := readAggregate(t, out3)
	if agg3.Aborted == "" || len(agg3.Cases) != 1 || agg3.Cases[0].Runs != 2 {
		t.Errorf("budget aggregate = aborted %q, cases %+v", agg3.Aborted, agg3.Cases)
	}
	if !strings.Contains(stderr, "exceeded --max-cost-usd $0.02") {
		t.Errorf("budget stderr = %q", stderr)
	}
}

func readAggregate(t *testing.T, outDir string) report.Aggregate {
	t.Helper()
	agg, err := report.ReadAggregate(filepath.Join(outDir, "aggregate-result.json"))
	if err != nil {
		t.Fatalf("ReadAggregate: %v", err)
	}
	return agg
}

func assertWholeSuiteAggregate(t *testing.T, outDir string) {
	t.Helper()
	agg := readAggregate(t, outDir)
	if agg.SchemaVersion != "1" || agg.Suite != "suite" || agg.Aborted != "" {
		t.Errorf("aggregate header = %+v", agg)
	}
	if len(agg.Cases) != 2 || agg.Cases[0].Name != "minimal" || agg.Cases[1].Name != "two-tools" {
		t.Fatalf("aggregate cases = %+v", agg.Cases)
	}
	minimal, twoTools := agg.Cases[0], agg.Cases[1]
	if minimal.Runs != 3 || minimal.Passed != 0 || minimal.PassRate != 0 || strings.Join(minimal.Tags, ",") != "medium" {
		t.Errorf("minimal summary = %+v", minimal)
	}
	if twoTools.Runs != 1 || twoTools.Passed != 1 || twoTools.PassRate != 1 || twoTools.Tier != "cheap" {
		t.Errorf("two-tools summary = %+v", twoTools)
	}
	// 4 agent runs at $0.0123 plus one judge call at $0.001.
	if !near(agg.Aggregates.TotalCostUSD, 4*0.0123+0.001) {
		t.Errorf("TotalCostUSD = %v, want %v", agg.Aggregates.TotalCostUSD, 4*0.0123+0.001)
	}
	if !near(agg.Aggregates.PassRate, 0.25) || !near(agg.Aggregates.AverageScore, 0.25) {
		t.Errorf("PassRate/AverageScore = %v/%v, want 0.25/0.25", agg.Aggregates.PassRate, agg.Aggregates.AverageScore)
	}
}

func assertTwoToolsRun(t *testing.T, outDir, suite string) {
	t.Helper()
	runDir := filepath.Join(outDir, "two-tools", "run-1")
	res, err := report.ReadRunResult(filepath.Join(runDir, "result.json"))
	if err != nil {
		t.Fatalf("ReadRunResult: %v", err)
	}
	if res.Case != "two-tools" || res.Run != 1 || res.Model != "claude-sonnet-5" || !res.Passed || res.Error != "" {
		t.Errorf("result header = %+v", res)
	}
	if res.CostUSD != 0.0123 || res.JudgeCostUSD != 0.001 || res.DurationMS != 1234 || res.NumTurns != 4 {
		t.Errorf("counters = cost %v judge %v duration %d turns %d", res.CostUSD, res.JudgeCostUSD, res.DurationMS, res.NumTurns)
	}
	if len(res.Graders) != 10 {
		t.Fatalf("graders = %d, want 10", len(res.Graders))
	}
	for _, g := range res.Graders {
		if !g.Passed {
			t.Errorf("grader %s (%s) failed: %s", g.Name, g.Type, g.Detail)
		}
	}
	if res.Graders[9].Name != "postcheck" || !strings.Contains(res.Graders[9].Detail, "go.mod present") {
		t.Errorf("postcheck outcome = %+v", res.Graders[9])
	}
	if res.ScaffoldDir == "" {
		t.Fatal("--keep-temp must record scaffold_dir")
	}
	if _, err := os.Stat(filepath.Join(res.ScaffoldDir, "hello.go")); err != nil {
		t.Errorf("kept scaffold dir lacks hello.go: %v", err)
	}
	for _, f := range []string{"trace.jsonl", "stderr.txt", "scaffold.txt", "postcheck.txt", "judge-judge.txt"} {
		if _, err := os.Stat(filepath.Join(runDir, f)); err != nil {
			t.Errorf("run artifact %s: %v", f, err)
		}
	}
	scaffoldLog, _ := os.ReadFile(filepath.Join(runDir, "scaffold.txt"))
	if !strings.Contains(string(scaffoldLog), "scaffolded "+res.ScaffoldDir) {
		t.Errorf("scaffold.txt = %q", scaffoldLog)
	}
	if !strings.HasPrefix(res.ScaffoldDir, os.TempDir()) || strings.HasPrefix(res.ScaffoldDir, suite) {
		t.Errorf("scaffold dir %q should live under the system temp dir", res.ScaffoldDir)
	}
}

// assertAgentArgs checks the exact claude command line from the contract; the
// fake records the last invocation, which is two-tools (sorted after minimal).
func assertAgentArgs(t *testing.T, argsOut, suite string) {
	t.Helper()
	data, err := os.ReadFile(argsOut)
	if err != nil {
		t.Fatalf("read fake argv: %v", err)
	}
	got := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	want := []string{
		"-p", "/go-ldd-review",
		"--plugin-dir", filepath.Dir(suite),
		"--output-format", "stream-json",
		"--verbose",
		"--model", "claude-sonnet-5",
		"--permission-mode", "bypassPermissions",
		"--max-turns", "5",
		"--no-session-persistence",
		"--append-system-prompt", "Be brief.", "", // the multi-line value spans two recorded lines
		"--allowedTools", "Bash,Read,Write,Skill",
	}
	if strings.Join(got, "\x00") != strings.Join(want, "\x00") {
		t.Errorf("claude argv:\n got %q\nwant %q", got, want)
	}
}

func assertMinimalRun(t *testing.T, outDir string) {
	t.Helper()
	for _, run := range []string{"run-1", "run-2", "run-3"} {
		res, err := report.ReadRunResult(filepath.Join(outDir, "minimal", run, "result.json"))
		if err != nil {
			t.Fatalf("ReadRunResult %s: %v", run, err)
		}
		if res.Passed || len(res.Graders) != 1 || res.Graders[0].Passed || !strings.Contains(res.Graders[0].Detail, "Agent called 0 time(s)") {
			t.Errorf("minimal %s = %+v", run, res)
		}
		if res.ScaffoldDir == "" {
			t.Errorf("minimal %s should record scaffold_dir under --keep-temp", run)
		}
	}
}

func TestRun_UsageErrors(t *testing.T) {
	t.Setenv("PATH", t.TempDir()) // no claude anywhere: a usage error must never reach the agent
	suite := abs(t, "../../testdata/suite")
	cases := []struct {
		name string
		args []string
	}{
		{name: "no args", args: nil},
		{name: "unknown command", args: []string{"list"}},
		{name: "missing evals dir", args: []string{"run"}},
		{name: "two positionals", args: []string{"run", suite, suite}},
		{name: "unknown flag", args: []string{"run", "--bogus", suite}},
		{name: "bad threshold", args: []string{"run", "--threshold", "2", suite}},
		{name: "negative budget", args: []string{"run", "--max-cost-usd", "-1", suite}},
		{name: "not a dir", args: []string{"run", filepath.Join(suite, "two-tools", "prompt.md")}},
		{name: "no case matches tag", args: []string{"run", "--tag", "nope", suite}},
		{name: "no case matches glob", args: []string{"run", "--case", "zzz-*", suite}},
		{name: "malformed glob", args: []string{"run", "--case", "[", suite}},
		{name: "out dir under a file", args: []string{"run", "--out", filepath.Join(suite, "two-tools", "prompt.md", "x"), suite}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			code, _, stderr := run(t, tc.args...)
			if code != cli.ExitUsage {
				t.Errorf("exit = %d, want %d (stderr %q)", code, cli.ExitUsage, stderr)
			}
			if stderr == "" {
				t.Error("usage errors must explain themselves on stderr")
			}
		})
	}
}
