package grade_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/grade"
	"example.com/ldd-eval/internal/trace"
)

func mustSelector(t *testing.T, tool, input string) grade.ToolSelector {
	t.Helper()
	sel, err := grade.NewToolSelector(tool, input)
	if err != nil {
		t.Fatalf("NewToolSelector(%q, %q): %v", tool, input, err)
	}
	return sel
}

func mustBounds(t *testing.T, lo, hi int, hasMax bool) grade.Bounds {
	t.Helper()
	b, err := grade.NewBounds(lo, hi, hasMax)
	if err != nil {
		t.Fatalf("NewBounds(%d, %d, %v): %v", lo, hi, hasMax, err)
	}
	return b
}

// threeCalls is Skill(code-designing) -> Bash(ls) -> Write(hello.go).
func threeCalls(t *testing.T) trace.Trace {
	t.Helper()
	return parseTrace(t,
		toolUse("Skill", `{"skill":"go-linter-driven-development:code-designing"}`),
		toolUse("Bash", `{"command":"ls"}`),
		toolUse("Write", `{"file_path":"hello.go","content":"package x"}`),
		resultEvent("done"),
	)
}

func TestNewToolSelector_Success(t *testing.T) {
	t.Parallel()
	plain := mustSelector(t, " Bash ", "")
	if plain.String() != "Bash" {
		t.Errorf("String() = %q, want Bash", plain.String())
	}
	if !plain.Matches(trace.ToolCall{Name: "Bash", Input: `{"command":"rm"}`}) {
		t.Error("selector without input_match must match any input")
	}
	if plain.Matches(trace.ToolCall{Name: "Read"}) {
		t.Error("selector must not match another tool")
	}
	filtered := mustSelector(t, "Write", `\.go"`)
	if filtered.String() != `Write(\.go")` {
		t.Errorf("String() = %q", filtered.String())
	}
	if !filtered.Matches(trace.ToolCall{Name: "Write", Input: `{"file_path":"a.go"}`}) {
		t.Error("input_match should match a .go path")
	}
	if filtered.Matches(trace.ToolCall{Name: "Write", Input: `{"file_path":"a.md"}`}) {
		t.Error("input_match should reject a .md path")
	}
}

func TestNewToolSelector_Error(t *testing.T) {
	t.Parallel()
	if _, err := grade.NewToolSelector("", "x"); !errors.Is(err, grade.ErrEmptyTool) {
		t.Errorf("empty tool error = %v, want ErrEmptyTool", err)
	}
	if _, err := grade.NewToolSelector("Bash", "("); err == nil {
		t.Error("bad input_match regex: want error, got nil")
	}
}

func TestNewBounds_Success(t *testing.T) {
	t.Parallel()
	cases := []struct {
		lo, hi int
		hasMax bool
		want   string
		in     []int
		out    []int
	}{
		{lo: 1, hi: 0, hasMax: false, want: ">= 1", in: []int{1, 5}, out: []int{0}},
		{lo: 0, hi: 0, hasMax: true, want: "exactly 0", in: []int{0}, out: []int{1}},
		{lo: 1, hi: 3, hasMax: true, want: "between 1 and 3", in: []int{1, 2, 3}, out: []int{0, 4}},
		{lo: 0, hi: 0, hasMax: false, want: ">= 0", in: []int{0, 100}, out: nil},
	}
	for _, tc := range cases {
		t.Run(tc.want, func(t *testing.T) {
			t.Parallel()
			b := mustBounds(t, tc.lo, tc.hi, tc.hasMax)
			if b.String() != tc.want {
				t.Errorf("String() = %q, want %q", b.String(), tc.want)
			}
			for _, n := range tc.in {
				if !b.Contains(n) {
					t.Errorf("Contains(%d) = false, want true", n)
				}
			}
			for _, n := range tc.out {
				if b.Contains(n) {
					t.Errorf("Contains(%d) = true, want false", n)
				}
			}
		})
	}
}

func TestNewBounds_Error(t *testing.T) {
	t.Parallel()
	if _, err := grade.NewBounds(-1, 0, false); !errors.Is(err, grade.ErrBadBounds) {
		t.Errorf("negative min error = %v, want ErrBadBounds", err)
	}
	if _, err := grade.NewBounds(2, 1, true); !errors.Is(err, grade.ErrBadBounds) {
		t.Errorf("max < min error = %v, want ErrBadBounds", err)
	}
}

func TestNewToolUsed_Error(t *testing.T) {
	t.Parallel()
	sel := mustSelector(t, "Bash", "")
	b := mustBounds(t, 1, 0, false)
	if _, err := grade.NewToolUsed("", sel, b); !errors.Is(err, grade.ErrEmptyName) {
		t.Errorf("empty name error = %v, want ErrEmptyName", err)
	}
	if _, err := grade.NewToolUsed("g", grade.ToolSelector{}, b); !errors.Is(err, grade.ErrEmptyTool) {
		t.Errorf("zero selector error = %v, want ErrEmptyTool", err)
	}
}

func TestToolUsed_Grade(t *testing.T) {
	t.Parallel()
	tr := threeCalls(t)
	cases := []struct {
		name   string
		tool   string
		input  string
		lo, hi int
		hasMax bool
		passed bool
	}{
		{name: "called once min 1", tool: "Bash", lo: 1, passed: true},
		{name: "input filter hit", tool: "Skill", input: "code-designing", lo: 1, passed: true},
		{name: "input filter miss", tool: "Skill", input: "pre-commit-review", lo: 1, passed: false},
		{name: "never called", tool: "Agent", lo: 1, passed: false},
		{name: "must not call satisfied", tool: "Agent", lo: 0, hi: 0, hasMax: true, passed: true},
		{name: "must not call violated", tool: "Write", lo: 0, hi: 0, hasMax: true, passed: false},
		{name: "max exceeded", tool: "Bash", lo: 0, hi: 0, hasMax: true, passed: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			g, err := grade.NewToolUsed("g", mustSelector(t, tc.tool, tc.input), mustBounds(t, tc.lo, tc.hi, tc.hasMax))
			if err != nil {
				t.Fatalf("NewToolUsed: %v", err)
			}
			out := g.Grade(context.Background(), grade.Subject{Trace: tr})
			if out.Passed != tc.passed {
				t.Errorf("Passed = %v (%s), want %v", out.Passed, out.Detail, tc.passed)
			}
			if out.Type != "tool_used" || !strings.Contains(out.Detail, "called") {
				t.Errorf("Outcome = %+v", out)
			}
		})
	}
}

func TestNewToolOrder_Error(t *testing.T) {
	t.Parallel()
	sel := mustSelector(t, "Bash", "")
	if _, err := grade.NewToolOrder("", sel, sel); !errors.Is(err, grade.ErrEmptyName) {
		t.Errorf("empty name error = %v, want ErrEmptyName", err)
	}
	if _, err := grade.NewToolOrder("g", sel, grade.ToolSelector{}); !errors.Is(err, grade.ErrEmptyTool) {
		t.Errorf("zero after error = %v, want ErrEmptyTool", err)
	}
	if _, err := grade.NewToolOrder("g", grade.ToolSelector{}, sel); !errors.Is(err, grade.ErrEmptyTool) {
		t.Errorf("zero before error = %v, want ErrEmptyTool", err)
	}
}

func TestToolOrder_Grade(t *testing.T) {
	t.Parallel()
	tr := threeCalls(t)
	cases := []struct {
		name         string
		before       [2]string
		after        [2]string
		passed       bool
		detailSubstr string
	}{
		{name: "skill before write", before: [2]string{"Skill", "code-designing"}, after: [2]string{"Write", `\.go"`}, passed: true, detailSubstr: "precedes"},
		{name: "reverse direction fails", before: [2]string{"Write", `\.go"`}, after: [2]string{"Skill", "code-designing"}, passed: false, detailSubstr: "does not precede"},
		{name: "before never called", before: [2]string{"Agent", ""}, after: [2]string{"Write", ""}, passed: false, detailSubstr: "Agent was never called"},
		{name: "after never called", before: [2]string{"Skill", ""}, after: [2]string{"Edit", ""}, passed: false, detailSubstr: "Edit was never called"},
		{name: "same tool cannot precede itself", before: [2]string{"Bash", ""}, after: [2]string{"Bash", ""}, passed: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			g, err := grade.NewToolOrder("g", mustSelector(t, tc.before[0], tc.before[1]), mustSelector(t, tc.after[0], tc.after[1]))
			if err != nil {
				t.Fatalf("NewToolOrder: %v", err)
			}
			if g.Name() != "g" || g.Type() != "tool_order" {
				t.Errorf("Name/Type = %q/%q", g.Name(), g.Type())
			}
			out := g.Grade(context.Background(), grade.Subject{Trace: tr})
			if out.Passed != tc.passed {
				t.Errorf("Passed = %v (%s), want %v", out.Passed, out.Detail, tc.passed)
			}
			if !strings.Contains(out.Detail, tc.detailSubstr) {
				t.Errorf("Detail = %q, want it to contain %q", out.Detail, tc.detailSubstr)
			}
		})
	}
}
