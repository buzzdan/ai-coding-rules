package grade_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/grade"
)

func TestParseTarget_Success(t *testing.T) {
	t.Parallel()
	cases := map[string]grade.Target{
		"":             grade.TargetLastMessage,
		"last_message": grade.TargetLastMessage,
		" trace ":      grade.TargetTrace,
		"files":        grade.TargetFiles,
	}
	for input, want := range cases {
		got, err := grade.ParseTarget(input)
		if err != nil {
			t.Fatalf("ParseTarget(%q): %v", input, err)
		}
		if got != want {
			t.Errorf("ParseTarget(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestParseTarget_Error(t *testing.T) {
	t.Parallel()
	if _, err := grade.ParseTarget("stdout"); !errors.Is(err, grade.ErrBadTarget) {
		t.Fatalf("ParseTarget error = %v, want ErrBadTarget", err)
	}
}

func TestCompilePattern_Success(t *testing.T) {
	t.Parallel()
	re, err := grade.CompilePattern("hello", "i")
	if err != nil {
		t.Fatalf("CompilePattern: %v", err)
	}
	if !re.MatchString("say HELLO") {
		t.Error("flag i should make the match case-insensitive")
	}
	re, err = grade.CompilePattern("^b$", "ms")
	if err != nil {
		t.Fatalf("CompilePattern: %v", err)
	}
	if !re.MatchString("a\nb\nc") {
		t.Error("flag m should anchor per line")
	}
}

func TestCompilePattern_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		pattern string
		flags   string
		wantErr error
	}{
		{name: "empty pattern", pattern: "  ", flags: "", wantErr: grade.ErrEmptyPattern},
		{name: "bad flag", pattern: "a", flags: "x", wantErr: grade.ErrBadFlags},
		{name: "bad regex", pattern: "(", flags: "", wantErr: nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := grade.CompilePattern(tc.pattern, tc.flags)
			if err == nil {
				t.Fatal("CompilePattern: want error, got nil")
			}
			if tc.wantErr != nil && !errors.Is(err, tc.wantErr) {
				t.Errorf("error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}

func TestNewRegex_Success(t *testing.T) {
	t.Parallel()
	g, err := grade.NewRegex(grade.RegexSpec{Name: "evidence", Pattern: `R[0-9]+ \|`})
	if err != nil {
		t.Fatalf("NewRegex: %v", err)
	}
	if g.Name() != "evidence" || g.Type() != "regex" {
		t.Errorf("Name/Type = %q/%q, want evidence/regex", g.Name(), g.Type())
	}
}

func TestNewRegex_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		spec    grade.RegexSpec
		wantErr error
	}{
		{name: "empty name", spec: grade.RegexSpec{Pattern: "a"}, wantErr: grade.ErrEmptyName},
		{name: "empty pattern", spec: grade.RegexSpec{Name: "g"}, wantErr: grade.ErrEmptyPattern},
		{name: "bad match", spec: grade.RegexSpec{Name: "g", Pattern: "a", Match: "maybe"}, wantErr: grade.ErrBadMatch},
		{name: "bad target", spec: grade.RegexSpec{Name: "g", Pattern: "a", Target: "stderr"}, wantErr: grade.ErrBadTarget},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := grade.NewRegex(tc.spec)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("NewRegex error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}

func TestRegex_Grade_LastMessage(t *testing.T) {
	t.Parallel()
	tr := parseTrace(t, resultEvent("R3 | a.go:1 | x\nR7 | b.go:9 | y\nno TODO here"))
	cases := []struct {
		name   string
		spec   grade.RegexSpec
		passed bool
	}{
		{name: "contains", spec: grade.RegexSpec{Name: "g", Pattern: `R[0-9]+ \| \S+:[0-9]+ \|`}, passed: true},
		{name: "contains miss", spec: grade.RegexSpec{Name: "g", Pattern: `R99`}, passed: false},
		{name: "not_contains", spec: grade.RegexSpec{Name: "g", Pattern: `FIXME`, Match: "not_contains"}, passed: true},
		{name: "not_contains hit", spec: grade.RegexSpec{Name: "g", Pattern: `TODO`, Match: "not_contains"}, passed: false},
		{name: "count exact", spec: grade.RegexSpec{Name: "g", Pattern: `R[0-9]+ \|`, Match: "count:2"}, passed: true},
		{name: "count off", spec: grade.RegexSpec{Name: "g", Pattern: `R[0-9]+ \|`, Match: "count:1"}, passed: false},
		{name: "flag i", spec: grade.RegexSpec{Name: "g", Pattern: `todo`, Flags: "i"}, passed: true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			g, err := grade.NewRegex(tc.spec)
			if err != nil {
				t.Fatalf("NewRegex: %v", err)
			}
			out := g.Grade(context.Background(), grade.Subject{Trace: tr})
			if out.Passed != tc.passed {
				t.Errorf("Passed = %v (%s), want %v", out.Passed, out.Detail, tc.passed)
			}
			if out.Name != "g" || out.Type != "regex" {
				t.Errorf("Outcome name/type = %q/%q", out.Name, out.Type)
			}
		})
	}
}

func TestRegex_Grade_Trace(t *testing.T) {
	t.Parallel()
	tr := parseTrace(t, toolUse("Skill", `{"skill":"code-designing"}`), resultEvent("done"))
	g, err := grade.NewRegex(grade.RegexSpec{Name: "g", Pattern: `"skill":"code-designing"`, Target: "trace"})
	if err != nil {
		t.Fatalf("NewRegex: %v", err)
	}
	if out := g.Grade(context.Background(), grade.Subject{Trace: tr}); !out.Passed {
		t.Errorf("trace target should see tool input: %s", out.Detail)
	}
	g, err = grade.NewRegex(grade.RegexSpec{Name: "g", Pattern: `code-designing`})
	if err != nil {
		t.Fatalf("NewRegex: %v", err)
	}
	if out := g.Grade(context.Background(), grade.Subject{Trace: tr}); out.Passed {
		t.Error("last_message target must not see tool input")
	}
}

func TestRegex_Grade_Files(t *testing.T) {
	t.Parallel()
	dir := writeTree(t, map[string]string{
		"a.go":             "package x\n\nfunc A() {}\n// TODO: later\n",
		"sub/b.go":         "package sub\n// TODO one\n// TODO two\n",
		".git/description": "TODO inside git must be skipped\n",
		"README.md":        "no markers\n",
	})
	cases := []struct {
		name   string
		spec   grade.RegexSpec
		passed bool
		detail string
	}{
		{name: "count lines across tree", spec: grade.RegexSpec{Name: "g", Pattern: `TODO`, Match: "count:3", Target: "files"}, passed: true, detail: "3 match(es)"},
		{name: "one line with two hits counts once", spec: grade.RegexSpec{Name: "g", Pattern: `O`, Match: "count:3", Target: "files"}, passed: true},
		{name: "not_contains", spec: grade.RegexSpec{Name: "g", Pattern: `panic\(`, Match: "not_contains", Target: "files"}, passed: true},
		{name: "contains anchored", spec: grade.RegexSpec{Name: "g", Pattern: `^package sub$`, Target: "files"}, passed: true},
		{name: "contains miss", spec: grade.RegexSpec{Name: "g", Pattern: `package zzz`, Target: "files"}, passed: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			g, err := grade.NewRegex(tc.spec)
			if err != nil {
				t.Fatalf("NewRegex: %v", err)
			}
			out := g.Grade(context.Background(), grade.Subject{Dir: dir})
			if out.Passed != tc.passed {
				t.Errorf("Passed = %v (%s), want %v", out.Passed, out.Detail, tc.passed)
			}
			if !strings.Contains(out.Detail, tc.detail) {
				t.Errorf("Detail = %q, want it to contain %q", out.Detail, tc.detail)
			}
		})
	}
}

func TestRegex_Grade_FilesMissingDirFails(t *testing.T) {
	t.Parallel()
	g, err := grade.NewRegex(grade.RegexSpec{Name: "g", Pattern: `x`, Target: "files"})
	if err != nil {
		t.Fatalf("NewRegex: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: "/nonexistent/ldd-eval-dir"})
	if out.Passed {
		t.Fatal("missing dir must fail")
	}
	if !strings.Contains(out.Detail, "files target") {
		t.Errorf("Detail = %q, want the walk error", out.Detail)
	}
}
