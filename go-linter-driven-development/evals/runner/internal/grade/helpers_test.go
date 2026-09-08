package grade_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"example.com/ldd-eval/internal/trace"
)

// parseTrace builds a Trace from inline stream-json lines.
func parseTrace(t *testing.T, lines ...string) trace.Trace {
	t.Helper()
	tr, err := trace.Parse(strings.NewReader(strings.Join(lines, "\n")))
	if err != nil {
		t.Fatalf("trace.Parse: %v", err)
	}
	return tr
}

func toolUse(name, input string) string {
	return `{"type":"assistant","message":{"content":[{"type":"tool_use","name":"` + name + `","input":` + input + `}]}}`
}

func resultEvent(text string) string {
	return `{"type":"result","subtype":"success","result":` + quote(text) + `,"total_cost_usd":0.01,"duration_ms":5,"num_turns":1}`
}

func quote(s string) string {
	return `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`).Replace(s) + `"`
}

// writeTree materialises files (path -> content) under a fresh temp dir.
func writeTree(t *testing.T, files map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for rel, content := range files {
		path := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatalf("mkdir: %v", err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return root
}

// useFakeClaude puts testdata/fake-claude.sh on PATH as `claude`.
func useFakeClaude(t *testing.T) {
	t.Helper()
	script, err := filepath.Abs("../../testdata/fake-claude.sh")
	if err != nil {
		t.Fatalf("abs: %v", err)
	}
	bin := t.TempDir()
	if err := os.Symlink(script, filepath.Join(bin, "claude")); err != nil {
		t.Fatalf("symlink: %v", err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
}
