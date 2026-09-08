// Package runner executes eval cases: scaffold a temp dir, run headless
// `claude -p`, grade the trace, write result.json per run and
// aggregate-result.json per suite, and stop on the cost budget.
package runner

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"example.com/ldd-eval/internal/evalcase"
	"example.com/ldd-eval/internal/grade"
	"example.com/ldd-eval/internal/report"
)

const (
	defaultModel      = "claude-sonnet-5"
	defaultJudgeModel = "claude-haiku-4-5"
	dirPerm           = 0o755
)

// ErrBudgetExceeded is returned by Run when cumulative cost passes --max-cost-usd.
var ErrBudgetExceeded = errors.New("runner: cumulative cost exceeded the budget")

// ErrNoCases is returned when no case matches the selection.
var ErrNoCases = errors.New("runner: no cases selected")

// Options are the CLI flags. Zero values take the documented defaults.
type Options struct {
	EvalsDir   string
	PluginDir  string    // default: parent of EvalsDir
	OutDir     string    // default: <EvalsDir>/results/<timestamp>
	Model      string    // default: the case's model, else claude-sonnet-5
	JudgeModel string    // default: claude-haiku-4-5
	CaseGlob   string    // path.Match glob over case names; empty = all
	Tag        string    // keep only cases with this tag; empty = all
	Runs       int       // 0 = the case's runs
	KeepTemp   bool      // keep scaffold dirs
	MaxCostUSD float64   // 0 = unlimited
	Threshold  float64   // per-case pass rate for exit 0
	Progress   io.Writer // nil = discard
	Now        time.Time // zero = time.Now()
}

// Runner is a validated, ready-to-run selection of cases.
type Runner struct {
	opts      Options
	cases     []evalcase.Case
	judge     grade.Judge
	budget    report.Budget
	threshold report.Threshold
	progress  io.Writer
}

// New resolves defaults, discovers and filters cases, and validates every
// option. It touches no network.
func New(opts Options) (*Runner, error) {
	opts, err := resolveOptions(opts)
	if err != nil {
		return nil, err
	}
	judge, err := grade.NewJudge(opts.JudgeModel)
	if err != nil {
		return nil, fmt.Errorf("runner: %w", err)
	}
	budget, err := report.NewBudget(opts.MaxCostUSD)
	if err != nil {
		return nil, fmt.Errorf("runner: %w", err)
	}
	threshold, err := report.NewThreshold(opts.Threshold)
	if err != nil {
		return nil, fmt.Errorf("runner: %w", err)
	}
	cases, err := selectCases(opts)
	if err != nil {
		return nil, err
	}
	return &Runner{opts: opts, cases: cases, judge: judge, budget: budget, threshold: threshold, progress: opts.Progress}, nil
}

func resolveOptions(opts Options) (Options, error) {
	abs, err := filepath.Abs(opts.EvalsDir)
	if err != nil {
		return Options{}, fmt.Errorf("runner: evals dir: %w", err)
	}
	if info, serr := os.Stat(abs); serr != nil || !info.IsDir() {
		return Options{}, fmt.Errorf("runner: evals dir %s is not a directory", abs)
	}
	opts.EvalsDir = abs
	if opts.Now.IsZero() {
		opts.Now = time.Now()
	}
	if opts.PluginDir == "" {
		opts.PluginDir = filepath.Dir(abs)
	}
	if opts.PluginDir, err = filepath.Abs(opts.PluginDir); err != nil {
		return Options{}, fmt.Errorf("runner: plugin dir: %w", err)
	}
	if opts.OutDir == "" {
		opts.OutDir = filepath.Join(abs, "results", opts.Now.Format("20060102-150405"))
	}
	if opts.JudgeModel == "" {
		opts.JudgeModel = defaultJudgeModel
	}
	if opts.Progress == nil {
		opts.Progress = io.Discard
	}
	return opts, nil
}

func selectCases(opts Options) ([]evalcase.Case, error) {
	all, err := evalcase.Discover(opts.EvalsDir)
	if err != nil {
		return nil, fmt.Errorf("runner: %w", err)
	}
	selected := make([]evalcase.Case, 0, len(all))
	for _, c := range all {
		keep, kerr := selects(opts, c)
		if kerr != nil {
			return nil, kerr
		}
		if keep {
			selected = append(selected, c)
		}
	}
	if len(selected) == 0 {
		return nil, fmt.Errorf("%w: glob=%q tag=%q in %s", ErrNoCases, opts.CaseGlob, opts.Tag, opts.EvalsDir)
	}
	return selected, nil
}

func selects(opts Options, c evalcase.Case) (bool, error) {
	if opts.Tag != "" && !c.HasTag(opts.Tag) {
		return false, nil
	}
	if opts.CaseGlob == "" {
		return true, nil
	}
	ok, err := c.MatchesGlob(opts.CaseGlob)
	if err != nil {
		return false, fmt.Errorf("runner: %w", err)
	}
	return ok, nil
}

// Cases returns the selected cases.
func (r *Runner) Cases() []evalcase.Case { return r.cases }

// OutDir returns the resolved output directory.
func (r *Runner) OutDir() string { return r.opts.OutDir }

// Threshold returns the validated pass-rate threshold.
func (r *Runner) Threshold() report.Threshold { return r.threshold }

// Run executes every selected case×run and writes aggregate-result.json. It
// returns ErrBudgetExceeded (after writing the aggregate) when the budget is
// blown; any other error is an infrastructure failure.
func (r *Runner) Run(ctx context.Context) (report.Aggregate, error) {
	if err := os.MkdirAll(r.opts.OutDir, dirPerm); err != nil {
		return report.Aggregate{}, fmt.Errorf("runner: out dir: %w", err)
	}
	started := time.Now()
	led := &ledger{budget: r.budget}
	summaries := make([]report.CaseSummary, 0, len(r.cases))
	aborted := false
	for _, c := range r.cases {
		summary, abort, err := r.runCase(ctx, c, led)
		if err != nil {
			return report.Aggregate{}, err
		}
		summaries = append(summaries, summary)
		if abort {
			aborted = true
			break
		}
	}
	return r.finish(started, summaries, aborted, led)
}

func (r *Runner) finish(started time.Time, summaries []report.CaseSummary, aborted bool, led *ledger) (report.Aggregate, error) {
	agg := report.NewAggregate(filepath.Base(r.opts.EvalsDir), started, time.Now(), summaries)
	if aborted {
		agg.Aborted = fmt.Sprintf("cumulative cost $%.4f exceeded --max-cost-usd %s", led.spent, r.budget)
	}
	path := filepath.Join(r.opts.OutDir, "aggregate-result.json")
	if err := report.WriteJSON(path, agg); err != nil {
		return report.Aggregate{}, fmt.Errorf("runner: %w", err)
	}
	r.logf("aggregate: passRate=%.2f averageScore=%.2f totalCostUSD=%.4f -> %s", agg.Aggregates.PassRate, agg.Aggregates.AverageScore, agg.Aggregates.TotalCostUSD, path)
	if aborted {
		return agg, ErrBudgetExceeded
	}
	return agg, nil
}

// ledger accumulates spend against the budget.
type ledger struct {
	budget report.Budget
	spent  float64
}

func (l *ledger) add(cost float64) bool {
	l.spent += cost
	return l.budget.Exceeded(l.spent)
}

func (r *Runner) runCase(ctx context.Context, c evalcase.Case, led *ledger) (report.CaseSummary, bool, error) {
	info := report.CaseInfo{Name: c.Name, Tier: c.Tier, Tags: c.Tags}
	results := make([]report.RunResult, 0, r.runsFor(c))
	for i := 1; i <= r.runsFor(c); i++ {
		res, err := r.runOnce(ctx, c, i)
		if err != nil {
			return report.CaseSummary{}, false, err
		}
		results = append(results, res)
		r.logf("%s run %d/%d: passed=%v cost=$%.4f turns=%d %s", c.Name, i, r.runsFor(c), res.Passed, res.TotalCostUSD(), res.NumTurns, res.Error)
		if led.add(res.TotalCostUSD()) {
			r.logf("budget %s exceeded after $%.4f; stopping", r.budget, led.spent)
			return report.SummarizeCase(info, results), true, nil
		}
	}
	return report.SummarizeCase(info, results), false, nil
}

func (r *Runner) runsFor(c evalcase.Case) int {
	if r.opts.Runs > 0 {
		return r.opts.Runs
	}
	return c.Runs
}

func (r *Runner) modelFor(c evalcase.Case) string {
	switch {
	case r.opts.Model != "":
		return r.opts.Model
	case c.Model != "":
		return c.Model
	default:
		return defaultModel
	}
}

// runEnv is the per-run working set.
type runEnv struct {
	caseDef evalcase.Case
	work    string
	outDir  string
}

func (r *Runner) runOnce(ctx context.Context, c evalcase.Case, i int) (report.RunResult, error) {
	outDir := filepath.Join(r.opts.OutDir, c.Name, fmt.Sprintf("run-%d", i))
	if err := os.MkdirAll(outDir, dirPerm); err != nil {
		return report.RunResult{}, fmt.Errorf("runner: run dir: %w", err)
	}
	work, err := os.MkdirTemp("", "ldd-eval-"+c.Name+"-")
	if err != nil {
		return report.RunResult{}, fmt.Errorf("runner: temp dir: %w", err)
	}
	res := report.RunResult{Case: c.Name, Run: i, Model: r.modelFor(c)}
	if r.opts.KeepTemp {
		res.ScaffoldDir = work
	} else {
		defer func() { _ = os.RemoveAll(work) }() // best-effort cleanup of the scaffold
	}
	res = r.execute(ctx, runEnv{caseDef: c, work: work, outDir: outDir}, res).Finish()
	if err := report.WriteJSON(filepath.Join(outDir, "result.json"), res); err != nil {
		return report.RunResult{}, fmt.Errorf("runner: %w", err)
	}
	return res, nil
}

// execute scaffolds, runs the agent and grades. Agent-side failures land in
// res.Error, never in a returned error.
func (r *Runner) execute(ctx context.Context, env runEnv, res report.RunResult) report.RunResult {
	if err := scaffold(ctx, env.caseDef.ScaffoldScript, env.work, env.outDir); err != nil {
		res.Error = err.Error()
		return res
	}
	tr, err := runAgent(ctx, agentSpec{
		Prompt: env.caseDef.Prompt, PluginDir: r.opts.PluginDir, Model: res.Model,
		MaxTurns: env.caseDef.MaxTurns, Timeout: env.caseDef.Timeout,
		AppendSystemPrompt: env.caseDef.AppendSystemPrompt, AllowedTools: env.caseDef.AllowedTools,
		WorkDir: env.work, OutDir: env.outDir,
	})
	if err != nil {
		res.Error = err.Error()
		return res
	}
	res.CostUSD, res.DurationMS, res.NumTurns = tr.CostUSD(), tr.DurationMS(), tr.NumTurns()
	if tr.IsError() {
		res.Graders = append(res.Graders, grade.Outcome{Name: "execution", Type: "execution", Detail: "claude reported is_error (" + tr.Subtype() + ")"})
	}
	subject := grade.Subject{Trace: tr, Dir: env.work, OutDir: env.outDir, Judge: r.judge}
	for _, g := range env.caseDef.Graders {
		out := g.Grade(ctx, subject)
		res.JudgeCostUSD += out.CostUSD
		res.Graders = append(res.Graders, out)
	}
	return res
}

func (r *Runner) logf(format string, args ...any) {
	_, _ = fmt.Fprintf(r.progress, format+"\n", args...) // progress output is advisory
}
