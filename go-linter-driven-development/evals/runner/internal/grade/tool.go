package grade

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"example.com/ldd-eval/internal/trace"
)

// ErrEmptyTool is returned when a tool selector has no tool name.
var ErrEmptyTool = errors.New("grade: tool name is required")

// ErrBadBounds is returned when min/max do not describe a range.
var ErrBadBounds = errors.New("grade: min must be >= 0 and max (when set) >= min")

// ToolSelector picks tool_use blocks by tool name and an optional regex over
// the compact JSON encoding of the input.
type ToolSelector struct {
	tool  string
	input *regexp.Regexp
}

// NewToolSelector validates and builds a selector; inputMatch may be empty.
func NewToolSelector(tool, inputMatch string) (ToolSelector, error) {
	tool = strings.TrimSpace(tool)
	if tool == "" {
		return ToolSelector{}, ErrEmptyTool
	}
	sel := ToolSelector{tool: tool}
	if strings.TrimSpace(inputMatch) == "" {
		return sel, nil
	}
	re, err := regexp.Compile(inputMatch)
	if err != nil {
		return ToolSelector{}, fmt.Errorf("grade: tool %s input_match: %w", tool, err)
	}
	sel.input = re
	return sel, nil
}

// Matches reports whether one tool call satisfies the selector.
func (s ToolSelector) Matches(c trace.ToolCall) bool {
	if c.Name != s.tool {
		return false
	}
	return s.input == nil || s.input.MatchString(c.Input)
}

// String renders the selector for detail messages.
func (s ToolSelector) String() string {
	if s.input == nil {
		return s.tool
	}
	return s.tool + "(" + s.input.String() + ")"
}

// firstIndex returns the position of the first matching call, or -1.
func (s ToolSelector) firstIndex(calls []trace.ToolCall) int {
	for i, c := range calls {
		if s.Matches(c) {
			return i
		}
	}
	return -1
}

func (s ToolSelector) count(calls []trace.ToolCall) int {
	n := 0
	for _, c := range calls {
		if s.Matches(c) {
			n++
		}
	}
	return n
}

// Bounds is the [min, max] call-count window of a tool_used grader; an unset
// max means unbounded.
type Bounds struct {
	lo int
	hi int // -1 == unbounded
}

// NewBounds builds a bounded window. hasMax=false ignores max.
func NewBounds(lo, hi int, hasMax bool) (Bounds, error) {
	if lo < 0 {
		return Bounds{}, fmt.Errorf("%w: min=%d", ErrBadBounds, lo)
	}
	if !hasMax {
		return Bounds{lo: lo, hi: -1}, nil
	}
	if hi < lo {
		return Bounds{}, fmt.Errorf("%w: min=%d max=%d", ErrBadBounds, lo, hi)
	}
	return Bounds{lo: lo, hi: hi}, nil
}

// Contains reports whether n is inside the window.
func (b Bounds) Contains(n int) bool {
	return n >= b.lo && (b.hi < 0 || n <= b.hi)
}

// String renders the window for detail messages.
func (b Bounds) String() string {
	if b.hi < 0 {
		return fmt.Sprintf(">= %d", b.lo)
	}
	if b.lo == b.hi {
		return fmt.Sprintf("exactly %d", b.lo)
	}
	return fmt.Sprintf("between %d and %d", b.lo, b.hi)
}

// ToolUsed asserts how many times a selected tool was called.
type ToolUsed struct {
	name   string
	sel    ToolSelector
	bounds Bounds
}

// NewToolUsed validates and builds a ToolUsed grader.
func NewToolUsed(name string, sel ToolSelector, bounds Bounds) (ToolUsed, error) {
	if strings.TrimSpace(name) == "" {
		return ToolUsed{}, ErrEmptyName
	}
	if sel.tool == "" {
		return ToolUsed{}, fmt.Errorf("grader %s: %w", name, ErrEmptyTool)
	}
	return ToolUsed{name: name, sel: sel, bounds: bounds}, nil
}

// Name implements Grader.
func (g ToolUsed) Name() string { return g.name }

// Type implements Grader.
func (g ToolUsed) Type() string { return "tool_used" }

// Grade implements Grader.
func (g ToolUsed) Grade(_ context.Context, s Subject) Outcome {
	n := g.sel.count(s.Trace.ToolCalls())
	detail := fmt.Sprintf("%s called %d time(s); want %s", g.sel, n, g.bounds)
	return verdict(g.name, g.Type(), g.bounds.Contains(n), detail)
}

// ToolOrder asserts that the first `before` call precedes the first `after`
// call; both must occur.
type ToolOrder struct {
	name   string
	before ToolSelector
	after  ToolSelector
}

// NewToolOrder validates and builds a ToolOrder grader.
func NewToolOrder(name string, before, after ToolSelector) (ToolOrder, error) {
	if strings.TrimSpace(name) == "" {
		return ToolOrder{}, ErrEmptyName
	}
	if before.tool == "" || after.tool == "" {
		return ToolOrder{}, fmt.Errorf("grader %s: before/after: %w", name, ErrEmptyTool)
	}
	return ToolOrder{name: name, before: before, after: after}, nil
}

// Name implements Grader.
func (g ToolOrder) Name() string { return g.name }

// Type implements Grader.
func (g ToolOrder) Type() string { return "tool_order" }

// Grade implements Grader.
func (g ToolOrder) Grade(_ context.Context, s Subject) Outcome {
	calls := s.Trace.ToolCalls()
	bi, ai := g.before.firstIndex(calls), g.after.firstIndex(calls)
	switch {
	case bi < 0:
		return failf(g.name, g.Type(), "%s was never called", g.before)
	case ai < 0:
		return failf(g.name, g.Type(), "%s was never called", g.after)
	case bi < ai:
		return verdict(g.name, g.Type(), true, fmt.Sprintf("%s (call #%d) precedes %s (call #%d)", g.before, bi+1, g.after, ai+1))
	default:
		return failf(g.name, g.Type(), "%s (call #%d) does not precede %s (call #%d)", g.before, bi+1, g.after, ai+1)
	}
}
