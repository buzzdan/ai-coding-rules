package runner_test

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/report"
	"example.com/ldd-eval/internal/runner"
)

// A trace whose final message says DONE and reports a cost the regrade must
// carry over untouched.
const doneTrace = `{"type":"assistant","message":{"content":[{"type":"text","text":"DONE"}]}}
{"type":"result","subtype":"success","is_error":false,"result":"DONE","total_cost_usd":0.5,"duration_ms":42,"num_turns":3}
`

const failingGrader = "---\ntype: regex\npattern: 'never-there'\n---\n"

const passingGrader = "---\ntype: regex\npattern: 'DONE'\n---\n"

// recordRun executes the probe case once with a fake claude so a trace and a
// result.json exist under outDir.
func recordRun(t *testing.T, evalsDir, outDir string) report.RunResult {
	t.Helper()
	catTrace(t, doneTrace)
	_, res := runProbe(t, runner.Options{EvalsDir: evalsDir, OutDir: outDir, Threshold: 1})
	return res
}

func TestRegrade_AppliesEditedGradersAndKeepsAgentCost(t *testing.T) {
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": failingGrader})
	outDir := t.TempDir()
	before := recordRun(t, evalsDir, outDir)
	if before.Passed {
		t.Fatalf("setup: the failing grader must fail first, got %+v", before)
	}
	if err := os.WriteFile(filepath.Join(evalsDir, "probe", "graders", "g.md"), []byte(passingGrader), 0o600); err != nil {
		t.Fatalf("edit grader: %v", err)
	}
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, OutDir: outDir, Threshold: 1})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	agg, err := r.Regrade(context.Background())
	if err != nil {
		t.Fatalf("Regrade: %v", err)
	}
	if agg.Aggregates.PassRate != 1 || len(agg.Cases) != 1 || agg.Cases[0].Results[0].CostUSD != 0.5 {
		t.Errorf("aggregate = %+v, want pass rate 1 with the recorded $0.50 carried over", agg)
	}
	after, err := report.ReadRunResult(filepath.Join(outDir, "probe", "run-1", "result.json"))
	if err != nil {
		t.Fatalf("read regraded result: %v", err)
	}
	if !after.Passed || after.CostUSD != 0.5 || after.NumTurns != 3 || after.Model != before.Model {
		t.Errorf("regraded result = %+v, want passed with cost/turns/model carried over from %+v", after, before)
	}
	if _, err := report.ReadAggregate(filepath.Join(outDir, "aggregate-result.json")); err != nil {
		t.Errorf("aggregate-result.json: %v", err)
	}
}

func TestRegrade_ScaffoldReadersFailClearlyWithoutKeptScaffold(t *testing.T) {
	fileGrader := "---\ntype: file_exists\npath: 'hello.go'\n---\n"
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": passingGrader, "graders/f.md": fileGrader})
	outDir := t.TempDir()
	recordRun(t, evalsDir, outDir) // scaffold not kept: KeepTemp is false
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, OutDir: outDir, Threshold: 1})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if _, err := r.Regrade(context.Background()); err != nil {
		t.Fatalf("Regrade: %v", err)
	}
	after, err := report.ReadRunResult(filepath.Join(outDir, "probe", "run-1", "result.json"))
	if err != nil {
		t.Fatalf("read regraded result: %v", err)
	}
	var fileOutcomeDetail string
	for _, g := range after.Graders {
		if g.Type == "file_exists" {
			fileOutcomeDetail = g.Detail
		}
	}
	if after.Passed || !strings.Contains(fileOutcomeDetail, "kept scaffold") {
		t.Errorf("regraded result = %+v, want the file_exists grader failed with the kept-scaffold detail", after)
	}
}

func TestRegrade_SkipsRunStillInFlight(t *testing.T) {
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": passingGrader})
	outDir := t.TempDir()
	recordRun(t, evalsDir, outDir)
	// A second run has started: its trace is being written but result.json is not there yet.
	inFlight := filepath.Join(outDir, "probe", "run-2")
	if err := os.MkdirAll(inFlight, 0o750); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(inFlight, "trace.jsonl"), []byte(doneTrace), 0o600); err != nil {
		t.Fatalf("write trace: %v", err)
	}
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, OutDir: outDir, Threshold: 1})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	agg, err := r.Regrade(context.Background())
	if err != nil {
		t.Fatalf("Regrade: %v", err)
	}
	if len(agg.Cases) != 1 || len(agg.Cases[0].Results) != 1 || agg.Cases[0].Results[0].Run != 1 {
		t.Errorf("aggregate = %+v, want exactly the finished run-1 regraded", agg)
	}
	if _, err := os.Stat(filepath.Join(inFlight, "result.json")); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("in-flight run must be left alone, stat result.json err = %v", err)
	}
}

func TestRun_ResumeReusesFinishedRunsAndExecutesTheRest(t *testing.T) {
	// runs: 2 — the first is recorded by hand as finished, the second must execute.
	prompt := "---\nname: probe\nruns: 2\nmodel: claude-opus-4-1\ntimeout_seconds: 1\n---\nGo.\n"
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": prompt, "graders/g.md": passingGrader})
	outDir := t.TempDir()
	finished := report.RunResult{Case: "probe", Run: 1, Model: "recorded", CostUSD: 9, NumTurns: 7, Passed: true}
	if err := os.MkdirAll(filepath.Join(outDir, "probe", "run-1"), 0o750); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := report.WriteJSON(filepath.Join(outDir, "probe", "run-1", "result.json"), finished); err != nil {
		t.Fatalf("write recorded result: %v", err)
	}
	catTrace(t, doneTrace)
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, OutDir: outDir, Threshold: 1, Resume: true})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	agg, err := r.Run(context.Background())
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(agg.Cases) != 1 || len(agg.Cases[0].Results) != 2 {
		t.Fatalf("aggregate = %+v, want one case with two runs", agg)
	}
	got := agg.Cases[0].Results
	if got[0].Model != "recorded" || got[0].CostUSD != 9 || got[0].NumTurns != 7 {
		t.Errorf("run-1 = %+v, want the recorded result reused untouched", got[0])
	}
	if got[1].Run != 2 || got[1].CostUSD != 0.5 || got[1].Model != "claude-opus-4-1" {
		t.Errorf("run-2 = %+v, want a fresh execution of the fake claude", got[1])
	}
	if agg.Aggregates.TotalCostUSD != 9.5 {
		t.Errorf("total cost = %v, want reused 9 + fresh 0.5", agg.Aggregates.TotalCostUSD)
	}
}

func TestRegrade_ErrorWithoutRecordedRuns(t *testing.T) {
	t.Parallel()
	evalsDir := evalsWithCase(t, "true\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": passingGrader})
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, OutDir: t.TempDir(), Threshold: 1})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if _, err := r.Regrade(context.Background()); !errors.Is(err, runner.ErrNoRuns) {
		t.Fatalf("Regrade error = %v, want ErrNoRuns", err)
	}
}
