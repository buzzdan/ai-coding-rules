package report_test

import (
	"errors"
	"math"
	"path/filepath"
	"testing"
	"time"

	"example.com/ldd-eval/internal/grade"
	"example.com/ldd-eval/internal/report"
)

func outcomes(passed ...bool) []grade.Outcome {
	out := make([]grade.Outcome, 0, len(passed))
	for i, p := range passed {
		out = append(out, grade.Outcome{Name: "g" + string(rune('a'+i)), Type: "regex", Passed: p})
	}
	return out
}

func near(a, b float64) bool { return math.Abs(a-b) < 1e-9 }

func TestRunResult_Finish(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		res  report.RunResult
		want bool
	}{
		{name: "all pass", res: report.RunResult{Graders: outcomes(true, true)}, want: true},
		{name: "one fails", res: report.RunResult{Graders: outcomes(true, false)}, want: false},
		{name: "no graders", res: report.RunResult{}, want: false},
		{name: "execution error", res: report.RunResult{Graders: outcomes(true), Error: "timed out"}, want: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if got := tc.res.Finish().Passed; got != tc.want {
				t.Errorf("Finish().Passed = %v, want %v", got, tc.want)
			}
		})
	}
}

func TestRunResult_ScoreAndCost(t *testing.T) {
	t.Parallel()
	r := report.RunResult{Graders: outcomes(true, false, true, false), CostUSD: 0.5, JudgeCostUSD: 0.25}
	if !near(r.Score(), 0.5) {
		t.Errorf("Score() = %v, want 0.5", r.Score())
	}
	if !near(r.TotalCostUSD(), 0.75) {
		t.Errorf("TotalCostUSD() = %v, want 0.75", r.TotalCostUSD())
	}
	if (report.RunResult{}).Score() != 0 {
		t.Error("Score() of zero graders must be 0")
	}
}

func TestSummarizeCase(t *testing.T) {
	t.Parallel()
	info := report.CaseInfo{Name: "review-full", Tier: "cheap", Tags: []string{"cheap", "review"}}
	results := []report.RunResult{{Passed: true}, {Passed: false}, {Passed: true}}
	s := report.SummarizeCase(info, results)
	if s.Name != "review-full" || s.Tier != "cheap" || len(s.Tags) != 2 {
		t.Errorf("identity not carried: %+v", s)
	}
	if s.Runs != 3 || s.Passed != 2 || !near(s.PassRate, 2.0/3.0) {
		t.Errorf("Runs/Passed/PassRate = %d/%d/%v, want 3/2/0.667", s.Runs, s.Passed, s.PassRate)
	}
	empty := report.SummarizeCase(info, nil)
	if empty.Runs != 0 || empty.PassRate != 0 {
		t.Errorf("empty summary = %+v, want zero runs and rate", empty)
	}
}

func TestNewAggregate(t *testing.T) {
	t.Parallel()
	started := time.Date(2026, 9, 8, 10, 0, 0, 0, time.UTC)
	finished := started.Add(time.Minute)
	cases := []report.CaseSummary{
		report.SummarizeCase(report.CaseInfo{Name: "a"}, []report.RunResult{
			{Passed: true, Graders: outcomes(true, true), CostUSD: 1, JudgeCostUSD: 0.5},
		}),
		report.SummarizeCase(report.CaseInfo{Name: "b"}, []report.RunResult{
			{Passed: false, Graders: outcomes(true, false), CostUSD: 2},
			{Passed: false, Graders: outcomes(false, false), CostUSD: 3},
		}),
	}
	a := report.NewAggregate("evals", started, finished, cases)
	if a.SchemaVersion != "1" || a.Suite != "evals" || !a.StartedAt.Equal(started) || !a.FinishedAt.Equal(finished) {
		t.Errorf("header = %+v", a)
	}
	if len(a.Cases) != 2 {
		t.Fatalf("Cases len = %d", len(a.Cases))
	}
	if !near(a.Aggregates.PassRate, 1.0/3.0) {
		t.Errorf("PassRate = %v, want 1/3", a.Aggregates.PassRate)
	}
	if !near(a.Aggregates.AverageScore, (1+0.5+0)/3) {
		t.Errorf("AverageScore = %v, want 0.5", a.Aggregates.AverageScore)
	}
	if !near(a.Aggregates.TotalCostUSD, 6.5) {
		t.Errorf("TotalCostUSD = %v, want 6.5", a.Aggregates.TotalCostUSD)
	}
	empty := report.NewAggregate("evals", started, finished, nil)
	if empty.Aggregates != (report.Totals{}) {
		t.Errorf("empty aggregates = %+v, want zeros", empty.Aggregates)
	}
}

func TestNewThreshold_Success(t *testing.T) {
	t.Parallel()
	th, err := report.NewThreshold(0.5)
	if err != nil {
		t.Fatalf("NewThreshold: %v", err)
	}
	if th.Value() != 0.5 {
		t.Errorf("Value() = %v", th.Value())
	}
	agg := report.Aggregate{Cases: []report.CaseSummary{{PassRate: 0.5}, {PassRate: 1}}}
	if !th.Met(agg) {
		t.Error("Met should be true when every case reaches the threshold")
	}
	agg.Cases[0].PassRate = 0.4
	if th.Met(agg) {
		t.Error("Met should be false when one case is below")
	}
	if th.Met(report.Aggregate{}) {
		t.Error("Met should be false with no cases")
	}
	if th.Met(report.Aggregate{Aborted: "budget", Cases: []report.CaseSummary{{PassRate: 1}}}) {
		t.Error("Met should be false for an aborted run")
	}
}

func TestNewThreshold_Error(t *testing.T) {
	t.Parallel()
	for _, v := range []float64{-0.1, 1.1} {
		if _, err := report.NewThreshold(v); !errors.Is(err, report.ErrBadThreshold) {
			t.Errorf("NewThreshold(%v) error = %v, want ErrBadThreshold", v, err)
		}
	}
}

func TestNewBudget_Success(t *testing.T) {
	t.Parallel()
	unlimited, err := report.NewBudget(0)
	if err != nil {
		t.Fatalf("NewBudget(0): %v", err)
	}
	if unlimited.Exceeded(1e9) || unlimited.String() != "unlimited" {
		t.Errorf("unlimited budget misbehaves: exceeded=%v string=%q", unlimited.Exceeded(1e9), unlimited)
	}
	one, err := report.NewBudget(1)
	if err != nil {
		t.Fatalf("NewBudget(1): %v", err)
	}
	if one.Exceeded(0.5) || one.Exceeded(1.0) {
		t.Error("spend at or under the limit must not exceed")
	}
	if !one.Exceeded(1.01) {
		t.Error("spend over the limit must exceed")
	}
	if one.String() != "$1.00" {
		t.Errorf("String() = %q", one.String())
	}
}

func TestNewBudget_Error(t *testing.T) {
	t.Parallel()
	if _, err := report.NewBudget(-1); !errors.Is(err, report.ErrBadBudget) {
		t.Errorf("NewBudget(-1) error = %v, want ErrBadBudget", err)
	}
}

func TestWriteJSON_RoundTrip(t *testing.T) {
	t.Parallel()
	dir := t.TempDir()
	res := report.RunResult{Case: "c", Run: 2, Model: "m", Graders: outcomes(true), CostUSD: 0.1, DurationMS: 42, NumTurns: 3}.Finish()
	resPath := filepath.Join(dir, "result.json")
	if err := report.WriteJSON(resPath, res); err != nil {
		t.Fatalf("WriteJSON: %v", err)
	}
	got, err := report.ReadRunResult(resPath)
	if err != nil {
		t.Fatalf("ReadRunResult: %v", err)
	}
	if got.Case != "c" || got.Run != 2 || !got.Passed || got.DurationMS != 42 || len(got.Graders) != 1 {
		t.Errorf("round trip = %+v", got)
	}
	agg := report.NewAggregate("s", time.Now(), time.Now(), []report.CaseSummary{report.SummarizeCase(report.CaseInfo{Name: "c"}, []report.RunResult{res})})
	aggPath := filepath.Join(dir, "aggregate-result.json")
	if err := report.WriteJSON(aggPath, agg); err != nil {
		t.Fatalf("WriteJSON: %v", err)
	}
	gotAgg, err := report.ReadAggregate(aggPath)
	if err != nil {
		t.Fatalf("ReadAggregate: %v", err)
	}
	if gotAgg.SchemaVersion != "1" || len(gotAgg.Cases) != 1 || gotAgg.Aggregates.PassRate != 1 {
		t.Errorf("aggregate round trip = %+v", gotAgg)
	}
}

func TestWriteJSON_Error(t *testing.T) {
	t.Parallel()
	if err := report.WriteJSON(filepath.Join(t.TempDir(), "missing", "x.json"), report.RunResult{}); err == nil {
		t.Error("WriteJSON into a missing dir: want error")
	}
	if err := report.WriteJSON(filepath.Join(t.TempDir(), "x.json"), make(chan int)); err == nil {
		t.Error("WriteJSON of an unencodable value: want error")
	}
}

func TestRead_Error(t *testing.T) {
	t.Parallel()
	missing := filepath.Join(t.TempDir(), "missing.json")
	if _, err := report.ReadRunResult(missing); err == nil {
		t.Error("ReadRunResult missing: want error")
	}
	if _, err := report.ReadAggregate(missing); err == nil {
		t.Error("ReadAggregate missing: want error")
	}
	bad := filepath.Join(t.TempDir(), "bad.json")
	if err := report.WriteJSON(bad, "not an object"); err != nil {
		t.Fatalf("WriteJSON: %v", err)
	}
	if _, err := report.ReadRunResult(bad); err == nil {
		t.Error("ReadRunResult of a string: want error")
	}
	if _, err := report.ReadAggregate(bad); err == nil {
		t.Error("ReadAggregate of a string: want error")
	}
}
