package grade_test

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/grade"
)

func writeScript(t *testing.T, body string, perm os.FileMode) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "postcheck.sh")
	if err := os.WriteFile(path, []byte("#!/usr/bin/env bash\nset -euo pipefail\n"+body), perm); err != nil {
		t.Fatalf("write script: %v", err)
	}
	return path
}

func TestNewPostcheck_Success(t *testing.T) {
	t.Parallel()
	g, err := grade.NewPostcheck(writeScript(t, "true\n", 0o755))
	if err != nil {
		t.Fatalf("NewPostcheck: %v", err)
	}
	if g.Name() != "postcheck" || g.Type() != "postcheck" {
		t.Errorf("Name/Type = %q/%q", g.Name(), g.Type())
	}
}

func TestNewPostcheck_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name   string
		script string
	}{
		{name: "relative", script: "postcheck.sh"},
		{name: "missing", script: filepath.Join(t.TempDir(), "nope.sh")},
		{name: "not executable", script: writeScript(t, "true\n", 0o644)},
		{name: "directory", script: t.TempDir()},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if _, err := grade.NewPostcheck(tc.script); !errors.Is(err, grade.ErrBadScript) {
				t.Fatalf("NewPostcheck error = %v, want ErrBadScript", err)
			}
		})
	}
}

func TestPostcheck_Grade_Success(t *testing.T) {
	t.Parallel()
	script := writeScript(t, `test "$PWD" = "$EVAL_DIR"
test -d "$EVAL_OUT"
echo "findings: none in $(basename "$EVAL_DIR")"
`, 0o755)
	g, err := grade.NewPostcheck(script)
	if err != nil {
		t.Fatalf("NewPostcheck: %v", err)
	}
	dir, outDir := t.TempDir(), t.TempDir()
	out := g.Grade(context.Background(), grade.Subject{Dir: dir, OutDir: outDir})
	if !out.Passed {
		t.Fatalf("Passed = false: %s", out.Detail)
	}
	want := "findings: none in " + filepath.Base(dir)
	if out.Detail != want {
		t.Errorf("Detail = %q, want %q", out.Detail, want)
	}
	saved, err := os.ReadFile(filepath.Join(outDir, "postcheck.txt"))
	if err != nil || strings.TrimSpace(string(saved)) != want {
		t.Errorf("postcheck.txt = %q, %v", saved, err)
	}
}

func TestPostcheck_Grade_LongOutputIsClipped(t *testing.T) {
	t.Parallel()
	g, err := grade.NewPostcheck(writeScript(t, "head -c 3000 /dev/zero | tr '\\0' 'x'\n", 0o755))
	if err != nil {
		t.Fatalf("NewPostcheck: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: t.TempDir()})
	if !out.Passed || !strings.HasSuffix(out.Detail, "…(truncated)") || len(out.Detail) > 2100 {
		t.Errorf("Detail len %d suffix %q, want clipped output", len(out.Detail), out.Detail[max(0, len(out.Detail)-20):])
	}
}

func TestPostcheck_Grade_Failure(t *testing.T) {
	t.Parallel()
	g, err := grade.NewPostcheck(writeScript(t, "echo 'race in cache'\necho 'stderr detail' >&2\nexit 3\n", 0o755))
	if err != nil {
		t.Fatalf("NewPostcheck: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: t.TempDir()})
	if out.Passed {
		t.Fatal("Passed = true, want false")
	}
	for _, want := range []string{"exit status 3", "race in cache", "stderr detail"} {
		if !strings.Contains(out.Detail, want) {
			t.Errorf("Detail = %q, want it to contain %q", out.Detail, want)
		}
	}
}
