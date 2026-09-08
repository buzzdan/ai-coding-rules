// Package grade implements the grader types of the `claude plugin eval` case
// format (regex, tool_used, tool_order, file_exists, llm) plus the runner's own
// postcheck grader. Every grader is a small validated value built by a
// constructor; grading is pure except for llm (spawns a judge) and postcheck
// (spawns the case's script).
package grade

import (
	"context"
	"fmt"

	"example.com/ldd-eval/internal/trace"
)

// Outcome is one grader's verdict as written to result.json.
type Outcome struct {
	Name    string  `json:"name"`
	Type    string  `json:"type"`
	Passed  bool    `json:"passed"`
	Detail  string  `json:"detail"`
	CostUSD float64 `json:"cost_usd,omitempty"`
}

// Subject is everything a grader may inspect after an agent run.
type Subject struct {
	// Trace is the parsed stream-json of the agent run.
	Trace trace.Trace
	// Dir is the kept scaffold directory the agent worked in.
	Dir string
	// OutDir is the per-run output directory (postcheck.txt, judge replies).
	OutDir string
	// Judge runs the second `claude -p` for llm graders.
	Judge Judge
}

// Grader is one assertion over a Subject. The interface is earned: six
// concrete graders implement it and the runner iterates them uniformly.
type Grader interface {
	Name() string
	Type() string
	Grade(ctx context.Context, s Subject) Outcome
}

func verdict(name, typ string, passed bool, detail string) Outcome {
	return Outcome{Name: name, Type: typ, Passed: passed, Detail: detail}
}

func failf(name, typ, format string, args ...any) Outcome {
	return Outcome{Name: name, Type: typ, Passed: false, Detail: fmt.Sprintf(format, args...)}
}

const maxDetail = 2000

// clip keeps Detail fields readable in result.json.
func clip(s string) string {
	if len(s) <= maxDetail {
		return s
	}
	return s[:maxDetail] + "…(truncated)"
}

// ScaffoldReader is implemented by graders that read the working tree the
// agent left behind; a regrade without a kept scaffold cannot run them.
type ScaffoldReader interface {
	NeedsScaffold() bool
}
