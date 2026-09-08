package grade

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ErrEmptyCriteria is returned when an llm grader has no criteria.
var ErrEmptyCriteria = errors.New("grade: llm criteria is required")

// ErrBadFocus is returned for an unsupported focus specification.
var ErrBadFocus = errors.New("grade: focus must be last_message or {source: file, path: ...}")

type focusKind int

const (
	focusLastMessage focusKind = iota
	focusFile
)

// Focus names the text the judge reads: the final assistant message or one
// file from the scaffold dir.
type Focus struct {
	kind focusKind
	path string
}

// FocusLastMessage is the default focus.
func FocusLastMessage() Focus { return Focus{kind: focusLastMessage} }

// FocusFile focuses the judge on a file relative to the scaffold dir.
func FocusFile(path string) (Focus, error) {
	path = strings.TrimSpace(path)
	if path == "" || filepath.IsAbs(path) {
		return Focus{}, fmt.Errorf("%w: file path must be non-empty and relative, got %q", ErrBadFocus, path)
	}
	return Focus{kind: focusFile, path: path}, nil
}

// String renders the focus for prompts and detail messages.
func (f Focus) String() string {
	if f.kind == focusFile {
		return "file " + f.path
	}
	return "last_message"
}

// text resolves the focus against the subject.
func (f Focus) text(s Subject) (string, error) {
	if f.kind == focusLastMessage {
		return s.Trace.LastMessage(), nil
	}
	data, err := os.ReadFile(filepath.Join(s.Dir, f.path))
	if err != nil {
		return "", fmt.Errorf("read focus file: %w", err)
	}
	return string(data), nil
}

// LLM asks a judge model for a PASS/FAIL verdict on the focus text.
type LLM struct {
	name     string
	criteria string
	rubric   string
	focus    Focus
}

// NewLLM validates and builds an LLM grader; rubric (the file body) may be
// empty.
func NewLLM(name, criteria, rubric string, focus Focus) (LLM, error) {
	if strings.TrimSpace(name) == "" {
		return LLM{}, ErrEmptyName
	}
	if strings.TrimSpace(criteria) == "" {
		return LLM{}, fmt.Errorf("grader %s: %w", name, ErrEmptyCriteria)
	}
	return LLM{name: name, criteria: strings.TrimSpace(criteria), rubric: strings.TrimSpace(rubric), focus: focus}, nil
}

// Name implements Grader.
func (g LLM) Name() string { return g.name }

// Type implements Grader.
func (g LLM) Type() string { return "llm" }

// Prompt renders the judge prompt for the given focus text.
func (g LLM) Prompt(focusText string) string {
	var b strings.Builder
	b.WriteString("You are grading the output of an automated coding agent for an evaluation suite.\n")
	b.WriteString("Decide whether the FOCUS text satisfies the CRITERIA, using the RUBRIC where given.\n")
	b.WriteString("Do not use tools. Reply with brief reasoning, then a final line that is exactly\n")
	b.WriteString("`VERDICT: PASS` or `VERDICT: FAIL`.\n\n")
	b.WriteString("## CRITERIA\n\n" + g.criteria + "\n\n")
	if g.rubric != "" {
		b.WriteString("## RUBRIC\n\n" + g.rubric + "\n\n")
	}
	b.WriteString("## FOCUS (" + g.focus.String() + ")\n\n")
	b.WriteString(focusText)
	b.WriteString("\n")
	return b.String()
}

// Grade implements Grader. A missing focus file fails without spending on the
// judge.
func (g LLM) Grade(ctx context.Context, s Subject) Outcome {
	focusText, err := g.focus.text(s)
	if err != nil {
		return failf(g.name, g.Type(), "%v", err)
	}
	v, err := s.Judge.Ask(ctx, g.Prompt(focusText))
	if err != nil {
		return failf(g.name, g.Type(), "judge: %v", err)
	}
	g.saveReply(s.OutDir, v.Reply)
	out := verdict(g.name, g.Type(), v.Passed, clip(fmt.Sprintf("judge %s: %s", s.Judge.Model(), v.Reply)))
	out.CostUSD = v.CostUSD
	return out
}

func (g LLM) saveReply(outDir, reply string) {
	if outDir == "" {
		return
	}
	_ = os.WriteFile(filepath.Join(outDir, "judge-"+g.name+".txt"), []byte(reply), 0o644) // best-effort artifact; the verdict is already in Outcome
}
