// Package report holds the pure result types written to result.json and
// aggregate-result.json and the arithmetic over them (scores, pass rates,
// thresholds, budgets).
package report

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"time"

	"example.com/ldd-eval/internal/grade"
)

// SchemaVersion is the aggregate-result.json schema version.
const SchemaVersion = "1"

// ErrBadThreshold is returned for a threshold outside [0, 1].
var ErrBadThreshold = errors.New("report: threshold must be within [0, 1]")

// ErrBadBudget is returned for a negative budget.
var ErrBadBudget = errors.New("report: max cost must be >= 0 (0 = unlimited)")

// RunResult is one case×run, as written to <out>/<case>/run-<i>/result.json.
type RunResult struct {
	Case         string          `json:"case"`
	Run          int             `json:"run"`
	Model        string          `json:"model"`
	Passed       bool            `json:"passed"`
	Graders      []grade.Outcome `json:"graders"`
	CostUSD      float64         `json:"cost_usd"`
	JudgeCostUSD float64         `json:"judge_cost_usd"`
	DurationMS   int64           `json:"duration_ms"`
	NumTurns     int             `json:"num_turns"`
	Error        string          `json:"error,omitempty"`
	ScaffoldDir  string          `json:"scaffold_dir,omitempty"`
}

// Finish sets Passed from the graders (all must pass; zero graders never pass)
// and returns the completed result.
func (r RunResult) Finish() RunResult {
	r.Passed = len(r.Graders) > 0 && r.Error == ""
	for _, g := range r.Graders {
		if !g.Passed {
			r.Passed = false
		}
	}
	return r
}

// Score is the fraction of graders that passed (0 when there are none).
func (r RunResult) Score() float64 {
	if len(r.Graders) == 0 {
		return 0
	}
	n := 0
	for _, g := range r.Graders {
		if g.Passed {
			n++
		}
	}
	return float64(n) / float64(len(r.Graders))
}

// TotalCostUSD is agent cost plus judge cost.
func (r RunResult) TotalCostUSD() float64 { return r.CostUSD + r.JudgeCostUSD }

// CaseSummary is one case's runs and pass rate.
type CaseSummary struct {
	Name     string      `json:"name"`
	Tier     string      `json:"tier,omitempty"`
	Tags     []string    `json:"tags,omitempty"`
	Runs     int         `json:"runs"`
	Passed   int         `json:"passed"`
	PassRate float64     `json:"passRate"`
	Results  []RunResult `json:"results"`
}

// CaseInfo is the identity a summary carries over from the case file.
type CaseInfo struct {
	Name string
	Tier string
	Tags []string
}

// SummarizeCase computes a case's pass rate over its runs.
func SummarizeCase(info CaseInfo, results []RunResult) CaseSummary {
	passed := 0
	for _, r := range results {
		if r.Passed {
			passed++
		}
	}
	s := CaseSummary{Name: info.Name, Tier: info.Tier, Tags: info.Tags, Runs: len(results), Passed: passed, Results: results}
	if len(results) > 0 {
		s.PassRate = float64(passed) / float64(len(results))
	}
	return s
}

// Totals are the suite-wide aggregates.
type Totals struct {
	PassRate     float64 `json:"passRate"`
	AverageScore float64 `json:"averageScore"`
	TotalCostUSD float64 `json:"totalCostUSD"`
}

// Aggregate is aggregate-result.json.
type Aggregate struct {
	SchemaVersion string        `json:"schemaVersion"`
	Suite         string        `json:"suite"`
	StartedAt     time.Time     `json:"startedAt"`
	FinishedAt    time.Time     `json:"finishedAt"`
	Aborted       string        `json:"aborted,omitempty"`
	Cases         []CaseSummary `json:"cases"`
	Aggregates    Totals        `json:"aggregates"`
}

// NewAggregate computes suite totals over the case summaries. PassRate and
// AverageScore are per run (not per case) so a 3-run case weighs three times a
// 1-run case.
func NewAggregate(suite string, started, finished time.Time, cases []CaseSummary) Aggregate {
	a := Aggregate{SchemaVersion: SchemaVersion, Suite: suite, StartedAt: started, FinishedAt: finished, Cases: cases}
	runs, passed, score := 0, 0, 0.0
	for _, c := range cases {
		for _, r := range c.Results {
			runs++
			score += r.Score()
			a.Aggregates.TotalCostUSD += r.TotalCostUSD()
			if r.Passed {
				passed++
			}
		}
	}
	if runs > 0 {
		a.Aggregates.PassRate = float64(passed) / float64(runs)
		a.Aggregates.AverageScore = score / float64(runs)
	}
	return a
}

// Threshold is the minimum per-case pass rate for exit code 0.
type Threshold struct {
	value float64
}

// NewThreshold validates a threshold within [0, 1].
func NewThreshold(v float64) (Threshold, error) {
	if v < 0 || v > 1 {
		return Threshold{}, fmt.Errorf("%w: got %v", ErrBadThreshold, v)
	}
	return Threshold{value: v}, nil
}

// Value returns the threshold.
func (t Threshold) Value() float64 { return t.value }

// Met reports whether every case's pass rate reaches the threshold. An
// aggregate with no cases or an abort never meets it.
func (t Threshold) Met(a Aggregate) bool {
	if len(a.Cases) == 0 || a.Aborted != "" {
		return false
	}
	for _, c := range a.Cases {
		if c.PassRate < t.value {
			return false
		}
	}
	return true
}

// Budget is the --max-cost-usd guard; zero means unlimited.
type Budget struct {
	limit float64
}

// NewBudget validates a non-negative limit.
func NewBudget(limit float64) (Budget, error) {
	if limit < 0 {
		return Budget{}, fmt.Errorf("%w: got %v", ErrBadBudget, limit)
	}
	return Budget{limit: limit}, nil
}

// Exceeded reports whether spent has gone past the limit.
func (b Budget) Exceeded(spent float64) bool {
	return b.limit > 0 && spent > b.limit
}

// String renders the budget for messages.
func (b Budget) String() string {
	if b.limit == 0 {
		return "unlimited"
	}
	return fmt.Sprintf("$%.2f", b.limit)
}

// WriteJSON writes v as indented JSON to path.
func WriteJSON(path string, v any) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return fmt.Errorf("report: encode %s: %w", path, err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("report: write %s: %w", path, err)
	}
	return nil
}

// ReadRunResult loads a result.json.
func ReadRunResult(path string) (RunResult, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return RunResult{}, fmt.Errorf("report: read %s: %w", path, err)
	}
	var r RunResult
	if err := json.Unmarshal(data, &r); err != nil {
		return RunResult{}, fmt.Errorf("report: decode %s: %w", path, err)
	}
	return r, nil
}

// ReadAggregate loads an aggregate-result.json.
func ReadAggregate(path string) (Aggregate, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Aggregate{}, fmt.Errorf("report: read %s: %w", path, err)
	}
	var a Aggregate
	if err := json.Unmarshal(data, &a); err != nil {
		return Aggregate{}, fmt.Errorf("report: decode %s: %w", path, err)
	}
	return a, nil
}
