package grade_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/grade"
)

func TestNewFileExists_Success(t *testing.T) {
	t.Parallel()
	g, err := grade.NewFileExists("snap", " snapshot/*.go ")
	if err != nil {
		t.Fatalf("NewFileExists: %v", err)
	}
	if g.Name() != "snap" || g.Type() != "file_exists" {
		t.Errorf("Name/Type = %q/%q, want snap/file_exists", g.Name(), g.Type())
	}
}

func TestNewFileExists_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		grader  string
		pattern string
		wantErr error
	}{
		{name: "empty name", grader: "", pattern: "*.go", wantErr: grade.ErrEmptyName},
		{name: "empty pattern", grader: "g", pattern: "", wantErr: grade.ErrBadGlob},
		{name: "absolute", grader: "g", pattern: "/etc/*.go", wantErr: grade.ErrBadGlob},
		{name: "malformed", grader: "g", pattern: "[", wantErr: grade.ErrBadGlob},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := grade.NewFileExists(tc.grader, tc.pattern)
			if !errors.Is(err, tc.wantErr) {
				t.Fatalf("NewFileExists error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}

func TestFileExists_Grade_Success(t *testing.T) {
	t.Parallel()
	dir := writeTree(t, map[string]string{"snapshot/a.go": "package snapshot\n", "snapshot/b.go": "package snapshot\n", "main.go": "package main\n"})
	g, err := grade.NewFileExists("snap", "snapshot/*.go")
	if err != nil {
		t.Fatalf("NewFileExists: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: dir})
	if !out.Passed {
		t.Fatalf("Passed = false: %s", out.Detail)
	}
	if !strings.Contains(out.Detail, "2 match(es)") || !strings.Contains(out.Detail, "snapshot/a.go") {
		t.Errorf("Detail = %q, want relative matches listed", out.Detail)
	}
}

func TestFileExists_Grade_NoMatchFails(t *testing.T) {
	t.Parallel()
	dir := writeTree(t, map[string]string{"main.go": "package main\n"})
	g, err := grade.NewFileExists("snap", "snapshot/*.go")
	if err != nil {
		t.Fatalf("NewFileExists: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: dir})
	if out.Passed {
		t.Fatal("Passed = true, want false")
	}
	if !strings.Contains(out.Detail, "no file matches snapshot/*.go") {
		t.Errorf("Detail = %q", out.Detail)
	}
}
