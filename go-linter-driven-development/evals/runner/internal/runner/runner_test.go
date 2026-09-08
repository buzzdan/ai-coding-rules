package runner_test

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"example.com/ldd-eval/internal/report"
	"example.com/ldd-eval/internal/runner"
)

const regexGrader = "---\ntype: regex\npattern: 'Findings'\n---\n"

const promptWithModel = "---\nname: probe\nruns: 1\nmodel: claude-opus-4-1\ntimeout_seconds: 1\n---\nGo.\n"

// fakeClaude installs script as `claude` ahead of everything else on PATH
// (the rest of PATH stays so scaffold scripts keep coreutils).
func fakeClaude(t *testing.T, script string) {
	t.Helper()
	bin := t.TempDir()
	if err := os.WriteFile(filepath.Join(bin, "claude"), []byte(script), 0o755); err != nil {
		t.Fatalf("write fake claude: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
}

// catTrace is a fake claude that streams the given trace text.
func catTrace(t *testing.T, traceText string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "trace.jsonl")
	if err := os.WriteFile(path, []byte(traceText), 0o644); err != nil {
		t.Fatalf("write trace: %v", err)
	}
	fakeClaude(t, "#!/bin/bash\ncat "+path+"\n")
}

// evalsWithCase builds a temp evals dir holding one case `probe` and a
// scaffold script with the given body.
func evalsWithCase(t *testing.T, scaffoldBody string, files map[string]string) string {
	t.Helper()
	evalsDir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(evalsDir, "scaffold"), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(evalsDir, "scaffold", "default.sh"), []byte("#!/bin/bash\n"+scaffoldBody), 0o755); err != nil {
		t.Fatalf("write scaffold: %v", err)
	}
	for rel, content := range files {
		path := filepath.Join(evalsDir, "probe", rel)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatalf("mkdir: %v", err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return evalsDir
}

func runProbe(t *testing.T, opts runner.Options) (report.Aggregate, report.RunResult) {
	t.Helper()
	r, err := runner.New(opts)
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	agg, err := r.Run(context.Background())
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if len(agg.Cases) != 1 || len(agg.Cases[0].Results) != 1 {
		t.Fatalf("aggregate = %+v, want one case with one run", agg)
	}
	return agg, agg.Cases[0].Results[0]
}

func TestRunner_ScaffoldFailureIsRecordedNotFatal(t *testing.T) {
	fakeClaude(t, "#!/bin/bash\necho 'must not run' >&2; exit 9\n")
	evalsDir := evalsWithCase(t, "echo 'disk full' >&2\nexit 7\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": regexGrader})
	now := time.Date(2026, 9, 8, 10, 15, 0, 0, time.UTC)
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, Threshold: 1, Now: now})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if want := filepath.Join(evalsDir, "results", "20260908-101500"); r.OutDir() != want {
		t.Errorf("default OutDir = %q, want %q", r.OutDir(), want)
	}
	agg, err := r.Run(context.Background())
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	res := agg.Cases[0].Results[0]
	if res.Passed || len(res.Graders) != 0 || !strings.Contains(res.Error, "scaffold") || !strings.Contains(res.Error, "disk full") {
		t.Errorf("result = %+v, want a scaffold error and no graders", res)
	}
	if res.Model != "claude-opus-4-1" {
		t.Errorf("Model = %q, want the case's model when no flag is given", res.Model)
	}
	if !r.Threshold().Met(agg) == false {
		t.Error("a failed run must not meet the threshold")
	}
}

func TestRunner_IncompleteTraceIsAnExecutionError(t *testing.T) {
	catTrace(t, `{"type":"assistant","message":{"content":[{"type":"text","text":"Findings: none"}]}}`+"\n")
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": regexGrader})
	_, res := runProbe(t, runner.Options{EvalsDir: evalsDir, OutDir: t.TempDir(), Threshold: 1, Model: "flag-model"})
	if res.Passed || len(res.Graders) != 0 || !strings.Contains(res.Error, "no result event") {
		t.Errorf("result = %+v, want an incomplete-trace error", res)
	}
	if res.Model != "flag-model" || res.CostUSD != 0 {
		t.Errorf("Model/CostUSD = %q/%v, want flag-model/0", res.Model, res.CostUSD)
	}
}

func TestRunner_IsErrorResultAddsExecutionGraderButStillGrades(t *testing.T) {
	catTrace(t, strings.Join([]string{
		`{"type":"assistant","message":{"content":[{"type":"text","text":"Findings: R3 | x.go:1 | y"}]}}`,
		`{"type":"result","subtype":"error_max_turns","is_error":true,"result":"","total_cost_usd":0.2,"duration_ms":9,"num_turns":10}`,
	}, "\n"))
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": regexGrader})
	agg, res := runProbe(t, runner.Options{EvalsDir: evalsDir, OutDir: t.TempDir(), Threshold: 1})
	if res.Passed || res.Error != "" || len(res.Graders) != 2 {
		t.Fatalf("result = %+v, want execution + regex graders and no infrastructure error", res)
	}
	if res.Graders[0].Name != "execution" || res.Graders[0].Passed || !strings.Contains(res.Graders[0].Detail, "error_max_turns") {
		t.Errorf("execution grader = %+v", res.Graders[0])
	}
	if res.Graders[1].Name != "g" || !res.Graders[1].Passed {
		t.Errorf("regex grader should still run over the assistant text: %+v", res.Graders[1])
	}
	if res.CostUSD != 0.2 || res.NumTurns != 10 || agg.Aggregates.TotalCostUSD != 0.2 {
		t.Errorf("counters = %+v / %+v", res, agg.Aggregates)
	}
}

func TestRunner_TimeoutKillsClaude(t *testing.T) {
	fakeClaude(t, "#!/bin/bash\nsleep 30\n")
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": regexGrader})
	start := time.Now()
	_, res := runProbe(t, runner.Options{EvalsDir: evalsDir, OutDir: t.TempDir(), Threshold: 1})
	if elapsed := time.Since(start); elapsed > 15*time.Second {
		t.Errorf("run took %v; the 1s timeout did not kill the agent", elapsed)
	}
	if res.Passed || !strings.Contains(res.Error, "timed out") {
		t.Errorf("result = %+v, want a timeout error", res)
	}
}

func TestRunner_CaseGlobAndTagSelect(t *testing.T) {
	fakeClaude(t, "#!/bin/bash\nexit 1\n")
	evalsDir := evalsWithCase(t, "mkdir -p \"$1\"\n", map[string]string{"prompt.md": "---\ntags: [cheap]\n---\nGo.\n", "graders/g.md": regexGrader})
	r, err := runner.New(runner.Options{EvalsDir: evalsDir, Tag: "cheap", CaseGlob: "pro*", Threshold: 0.5})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	if len(r.Cases()) != 1 || r.Cases()[0].Name != "probe" || r.Threshold().Value() != 0.5 {
		t.Errorf("selection = %+v", r.Cases())
	}
}

func TestNew_Error(t *testing.T) {
	t.Parallel()
	evalsDir := evalsWithCase(t, "true\n", map[string]string{"prompt.md": promptWithModel, "graders/g.md": regexGrader})
	cases := []struct {
		name    string
		opts    runner.Options
		wantErr error
	}{
		{name: "missing evals dir", opts: runner.Options{EvalsDir: filepath.Join(evalsDir, "nope")}},
		{name: "evals dir is a file", opts: runner.Options{EvalsDir: filepath.Join(evalsDir, "probe", "prompt.md")}},
		{name: "bad threshold", opts: runner.Options{EvalsDir: evalsDir, Threshold: 1.5}, wantErr: report.ErrBadThreshold},
		{name: "bad budget", opts: runner.Options{EvalsDir: evalsDir, MaxCostUSD: -1}, wantErr: report.ErrBadBudget},
		{name: "no case for tag", opts: runner.Options{EvalsDir: evalsDir, Tag: "expensive"}, wantErr: runner.ErrNoCases},
		{name: "malformed glob", opts: runner.Options{EvalsDir: evalsDir, CaseGlob: "["}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := runner.New(tc.opts)
			if err == nil {
				t.Fatal("New: want error, got nil")
			}
			if tc.wantErr != nil && !errors.Is(err, tc.wantErr) {
				t.Errorf("New error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}
