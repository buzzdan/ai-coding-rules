package grade

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
)

// Target names what a regex grader searches.
type Target string

const (
	// TargetLastMessage searches the final assistant message.
	TargetLastMessage Target = "last_message"
	// TargetTrace searches the raw stream-json text.
	TargetTrace Target = "trace"
	// TargetFiles searches every file under the scaffold dir (excluding .git),
	// counting matching lines.
	TargetFiles Target = "files"
)

// ErrBadTarget is returned for an unknown `target:` value.
var ErrBadTarget = errors.New("grade: target must be last_message, trace or files")

// ErrBadFlags is returned for a regex flag outside i, m, s.
var ErrBadFlags = errors.New("grade: flags may only contain i, m, s")

// ErrEmptyPattern is returned when a regex grader has no pattern.
var ErrEmptyPattern = errors.New("grade: pattern is required")

// ErrEmptyName is returned when a grader is built without a name.
var ErrEmptyName = errors.New("grade: grader name is required")

// ParseTarget parses the `target:` field; empty means last_message.
func ParseTarget(s string) (Target, error) {
	switch t := Target(strings.TrimSpace(s)); t {
	case "":
		return TargetLastMessage, nil
	case TargetLastMessage, TargetTrace, TargetFiles:
		return t, nil
	default:
		return "", fmt.Errorf("%w: got %q", ErrBadTarget, s)
	}
}

// CompilePattern compiles an RE2 pattern with the grader-file flag letters
// (i, m, s) folded in as a `(?ims)` prefix.
func CompilePattern(pattern, flags string) (*regexp.Regexp, error) {
	if strings.TrimSpace(pattern) == "" {
		return nil, ErrEmptyPattern
	}
	for _, f := range flags {
		if !strings.ContainsRune("ims", f) {
			return nil, fmt.Errorf("%w: got %q", ErrBadFlags, flags)
		}
	}
	if flags != "" {
		pattern = "(?" + flags + ")" + pattern
	}
	re, err := regexp.Compile(pattern)
	if err != nil {
		return nil, fmt.Errorf("grade: compile pattern: %w", err)
	}
	return re, nil
}

// RegexSpec is the frontmatter of a `type: regex` grader file.
type RegexSpec struct {
	Name    string
	Pattern string
	Flags   string
	Match   string
	Target  string
}

// Regex asserts a pattern against last_message, the raw trace, or the files
// tree.
type Regex struct {
	name   string
	re     *regexp.Regexp
	match  Match
	target Target
}

// NewRegex validates and builds a Regex grader.
func NewRegex(spec RegexSpec) (Regex, error) {
	if strings.TrimSpace(spec.Name) == "" {
		return Regex{}, ErrEmptyName
	}
	re, err := CompilePattern(spec.Pattern, spec.Flags)
	if err != nil {
		return Regex{}, fmt.Errorf("grader %s: %w", spec.Name, err)
	}
	match, err := ParseMatch(spec.Match)
	if err != nil {
		return Regex{}, fmt.Errorf("grader %s: %w", spec.Name, err)
	}
	target, err := ParseTarget(spec.Target)
	if err != nil {
		return Regex{}, fmt.Errorf("grader %s: %w", spec.Name, err)
	}
	return Regex{name: spec.Name, re: re, match: match, target: target}, nil
}

// Name implements Grader.
func (g Regex) Name() string { return g.name }

// Type implements Grader.
func (g Regex) Type() string { return "regex" }

// Grade implements Grader.
func (g Regex) Grade(_ context.Context, s Subject) Outcome {
	hits, err := g.hits(s)
	if err != nil {
		return failf(g.name, g.Type(), "regex %s over %s: %v", g.re, g.target, err)
	}
	passed, detail := g.match.Evaluate(hits)
	return verdict(g.name, g.Type(), passed, fmt.Sprintf("%s over %s: %s", g.re, g.target, detail))
}

func (g Regex) hits(s Subject) (int, error) {
	switch g.target {
	case TargetTrace:
		return len(g.re.FindAllStringIndex(s.Trace.Raw(), -1)), nil
	case TargetFiles:
		return countMatchingLines(s.Dir, g.re)
	default: // TargetLastMessage is the default target
		return len(g.re.FindAllStringIndex(s.Trace.LastMessage(), -1)), nil
	}
}
