package runner

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"example.com/ldd-eval/internal/evalcase"
	"example.com/ldd-eval/internal/grade"
	"example.com/ldd-eval/internal/report"
	"example.com/ldd-eval/internal/trace"
)

// ErrNoRuns is returned when the output directory holds no trace for any
// selected case.
var ErrNoRuns = errors.New("runner: no recorded runs to regrade")

const scaffoldNeeded = "regrade: this grader needs the kept scaffold (rerun with --keep-temp)"

// Regrade re-applies the cases' current graders to traces already recorded
// under OutDir, so grader calibration never re-spends on agents. Agent cost,
// turns, model, and error are carried over from each run's result.json;
// judge cost is whatever the llm graders spend now. Graders that inspect the
// scaffold fail with a clear detail when the scaffold was not kept.
func (r *Runner) Regrade(ctx context.Context) (report.Aggregate, error) {
	started := time.Now()
	summaries := make([]report.CaseSummary, 0, len(r.cases))
	total := 0
	for _, c := range r.cases {
		results, err := r.regradeCase(ctx, c)
		if err != nil {
			return report.Aggregate{}, err
		}
		total += len(results)
		if len(results) > 0 {
			summaries = append(summaries, report.SummarizeCase(report.CaseInfo{Name: c.Name, Tier: c.Tier, Tags: c.Tags}, results))
		}
	}
	if total == 0 {
		return report.Aggregate{}, fmt.Errorf("%w: under %s", ErrNoRuns, r.opts.OutDir)
	}
	return r.finish(started, summaries, false, &ledger{budget: r.budget})
}

func (r *Runner) regradeCase(ctx context.Context, c evalcase.Case) ([]report.RunResult, error) {
	runDirs, err := recordedRuns(filepath.Join(r.opts.OutDir, c.Name))
	if err != nil {
		return nil, err
	}
	results := make([]report.RunResult, 0, len(runDirs))
	for _, dir := range runDirs {
		res, err := r.regradeRun(ctx, c, dir)
		if err != nil {
			return nil, err
		}
		results = append(results, res)
		r.logf("%s %s: regraded passed=%v (judge $%.4f)", c.Name, filepath.Base(dir), res.Passed, res.JudgeCostUSD)
	}
	return results, nil
}

// recordedRuns lists <caseDir>/run-<i> directories that hold a trace, in
// run order.
func recordedRuns(caseDir string) ([]string, error) {
	matches, err := filepath.Glob(filepath.Join(caseDir, "run-*", "trace.jsonl"))
	if err != nil {
		return nil, fmt.Errorf("runner: %w", err)
	}
	dirs := make([]string, 0, len(matches))
	for _, m := range matches {
		dirs = append(dirs, filepath.Dir(m))
	}
	sort.Slice(dirs, func(i, j int) bool { return runIndex(dirs[i]) < runIndex(dirs[j]) })
	return dirs, nil
}

func runIndex(dir string) int {
	n, err := strconv.Atoi(strings.TrimPrefix(filepath.Base(dir), "run-"))
	if err != nil {
		return 0
	}
	return n
}

func (r *Runner) regradeRun(ctx context.Context, c evalcase.Case, dir string) (report.RunResult, error) {
	prev, err := report.ReadRunResult(filepath.Join(dir, "result.json"))
	if err != nil {
		return report.RunResult{}, fmt.Errorf("runner: %w", err)
	}
	tr, err := trace.ParseFile(filepath.Join(dir, "trace.jsonl"))
	if err != nil {
		return report.RunResult{}, fmt.Errorf("runner: %w", err)
	}
	res := report.RunResult{Case: c.Name, Run: prev.Run, Model: prev.Model, CostUSD: prev.CostUSD, DurationMS: prev.DurationMS, NumTurns: prev.NumTurns, Error: prev.Error, ScaffoldDir: prev.ScaffoldDir}
	if res.Run == 0 {
		res.Run = runIndex(dir)
	}
	res.Graders = r.regradeGraders(ctx, c, grade.Subject{Trace: tr, Dir: keptScaffold(prev.ScaffoldDir), OutDir: dir, Judge: r.judge})
	for _, g := range res.Graders {
		res.JudgeCostUSD += g.CostUSD
	}
	res = res.Finish()
	if err := report.WriteJSON(filepath.Join(dir, "result.json"), res); err != nil {
		return report.RunResult{}, fmt.Errorf("runner: %w", err)
	}
	return res, nil
}

// keptScaffold returns the scaffold path when it still exists, else "".
func keptScaffold(path string) string {
	if path == "" {
		return ""
	}
	if info, err := os.Stat(path); err != nil || !info.IsDir() {
		return ""
	}
	return path
}

func (r *Runner) regradeGraders(ctx context.Context, c evalcase.Case, subject grade.Subject) []grade.Outcome {
	outcomes := make([]grade.Outcome, 0, len(c.Graders))
	for _, g := range c.Graders {
		if subject.Dir == "" && readsScaffold(g) {
			outcomes = append(outcomes, grade.Outcome{Name: g.Name(), Type: g.Type(), Passed: false, Detail: scaffoldNeeded})
			continue
		}
		outcomes = append(outcomes, g.Grade(ctx, subject))
	}
	return outcomes
}

// readsScaffold reports whether a grader inspects the working tree.
func readsScaffold(g grade.Grader) bool {
	sr, ok := g.(grade.ScaffoldReader)
	return ok && sr.NeedsScaffold()
}
