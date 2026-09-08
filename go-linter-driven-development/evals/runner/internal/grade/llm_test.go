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

func TestFocus(t *testing.T) {
	t.Parallel()
	if got := grade.FocusLastMessage().String(); got != "last_message" {
		t.Errorf("FocusLastMessage().String() = %q", got)
	}
	f, err := grade.FocusFile(" services/heartbeat.go ")
	if err != nil {
		t.Fatalf("FocusFile: %v", err)
	}
	if f.String() != "file services/heartbeat.go" {
		t.Errorf("FocusFile().String() = %q", f.String())
	}
	if _, err := grade.FocusFile(""); !errors.Is(err, grade.ErrBadFocus) {
		t.Errorf("empty path error = %v, want ErrBadFocus", err)
	}
	if _, err := grade.FocusFile("/abs/path.go"); !errors.Is(err, grade.ErrBadFocus) {
		t.Errorf("absolute path error = %v, want ErrBadFocus", err)
	}
	if got := (grade.Focus{}).String(); got != "last_message" {
		t.Errorf("zero Focus.String() = %q, want last_message", got)
	}
	ff, err := grade.FocusFiles([]string{"a/x.go", " b/y.go "})
	if err != nil {
		t.Fatalf("FocusFiles: %v", err)
	}
	if ff.String() != "files a/x.go, b/y.go" {
		t.Errorf("FocusFiles().String() = %q", ff.String())
	}
	if _, err := grade.FocusFiles(nil); !errors.Is(err, grade.ErrBadFocus) {
		t.Errorf("empty paths error = %v, want ErrBadFocus", err)
	}
	if _, err := grade.FocusFiles([]string{"ok.go", "/abs.go"}); !errors.Is(err, grade.ErrBadFocus) {
		t.Errorf("absolute path in list error = %v, want ErrBadFocus", err)
	}
}

func TestLLM_Grade_FilesFocusRendersEachFileUnderItsPath(t *testing.T) {
	useFakeClaude(t)
	dir := writeTree(t, map[string]string{"a/x.go": "package a\n", "b/y.go": "package b\n"})
	outDir := t.TempDir()
	focus, err := grade.FocusFiles([]string{"a/x.go", "b/y.go"})
	if err != nil {
		t.Fatalf("FocusFiles: %v", err)
	}
	g, err := grade.NewLLM("art", "c", "r", focus)
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	judge, err := grade.NewJudge("fake-judge")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: dir, OutDir: outDir, Judge: judge})
	if !out.Passed {
		t.Fatalf("Outcome = %+v, want PASS from the fake judge", out)
	}
	// The prompt the fake judge saw is what the real one would see.
	p := g.Prompt("### a/x.go\n\npackage a\n\n\n### b/y.go\n\npackage b\n\n\n")
	if !strings.Contains(p, "## FOCUS (files a/x.go, b/y.go)") || !strings.Contains(p, "### b/y.go\n\npackage b") {
		t.Errorf("prompt = %q, want both files under their path headings", p)
	}
	// A directory member stands for its non-test .go files, in name order.
	dirTree := writeTree(t, map[string]string{"pkg/b.go": "package pkg // b\n", "pkg/a.go": "package pkg // a\n", "pkg/a_test.go": "package pkg_test\n", "pkg/notes.md": "x\n"})
	dirFocus, _ := grade.FocusFiles([]string{"pkg"})
	g3, _ := grade.NewLLM("art", "c", "", dirFocus)
	if out := g3.Grade(context.Background(), grade.Subject{Dir: dirTree, OutDir: t.TempDir(), Judge: judge}); !out.Passed {
		t.Errorf("dir focus outcome = %+v, want PASS from the fake judge", out)
	}
	prompt := g3.Prompt("### pkg/a.go\n\npackage pkg // a\n\n\n### pkg/b.go\n\npackage pkg // b\n\n\n")
	if strings.Index(prompt, "### pkg/a.go") > strings.Index(prompt, "### pkg/b.go") || strings.Contains(prompt, "a_test.go") {
		t.Errorf("dir focus must render a.go before b.go and skip tests, got %q", prompt)
	}
	// A missing member fails before the judge is consulted.
	partial, _ := grade.FocusFiles([]string{"a/x.go", "missing.go"})
	g2, _ := grade.NewLLM("art", "c", "", partial)
	if out := g2.Grade(context.Background(), grade.Subject{Dir: dir}); out.Passed || !strings.Contains(out.Detail, "read focus file") {
		t.Errorf("missing member outcome = %+v, want a read-focus failure", out)
	}
}

func TestNewLLM_Error(t *testing.T) {
	t.Parallel()
	if _, err := grade.NewLLM("", "c", "", grade.FocusLastMessage()); !errors.Is(err, grade.ErrEmptyName) {
		t.Errorf("empty name error = %v, want ErrEmptyName", err)
	}
	if _, err := grade.NewLLM("g", "  ", "", grade.FocusLastMessage()); !errors.Is(err, grade.ErrEmptyCriteria) {
		t.Errorf("empty criteria error = %v, want ErrEmptyCriteria", err)
	}
}

func TestLLM_Prompt(t *testing.T) {
	t.Parallel()
	g, err := grade.NewLLM("altitude", "The function reads as a story.", "Cite the falsifying questions.\n", grade.FocusLastMessage())
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	if g.Name() != "altitude" || g.Type() != "llm" {
		t.Errorf("Name/Type = %q/%q", g.Name(), g.Type())
	}
	p := g.Prompt("the agent said this")
	for _, want := range []string{"## CRITERIA\n\nThe function reads as a story.", "## RUBRIC\n\nCite the falsifying questions.", "## FOCUS (last_message)\n\nthe agent said this", "VERDICT: PASS", "VERDICT: FAIL"} {
		if !strings.Contains(p, want) {
			t.Errorf("Prompt missing %q:\n%s", want, p)
		}
	}
	noRubric, err := grade.NewLLM("g", "c", "", grade.FocusLastMessage())
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	if strings.Contains(noRubric.Prompt("x"), "## RUBRIC") {
		t.Error("empty rubric must not render a RUBRIC section")
	}
}

func TestLLM_Grade_MissingFocusFileFailsWithoutJudge(t *testing.T) {
	t.Parallel()
	focus, err := grade.FocusFile("services/missing.go")
	if err != nil {
		t.Fatalf("FocusFile: %v", err)
	}
	g, err := grade.NewLLM("g", "c", "", focus)
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	// Zero Judge: if Grade tried to consult it the outcome would mention "judge".
	out := g.Grade(context.Background(), grade.Subject{Dir: t.TempDir()})
	if out.Passed || !strings.Contains(out.Detail, "read focus file") {
		t.Errorf("Outcome = %+v, want a read-focus failure", out)
	}
}

func TestLLM_Grade_FileFocusWithFakeJudge(t *testing.T) {
	useFakeClaude(t)
	dir := writeTree(t, map[string]string{"services/heartbeat.go": "package services\n"})
	outDir := t.TempDir()
	focus, err := grade.FocusFile("services/heartbeat.go")
	if err != nil {
		t.Fatalf("FocusFile: %v", err)
	}
	g, err := grade.NewLLM("altitude", "c", "r", focus)
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	judge, err := grade.NewJudge("fake-judge")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Dir: dir, OutDir: outDir, Judge: judge})
	if !out.Passed || out.CostUSD != 0.001 {
		t.Fatalf("Outcome = %+v, want PASS at $0.001", out)
	}
	if !strings.Contains(out.Detail, "judge fake-judge") {
		t.Errorf("Detail = %q", out.Detail)
	}
	reply, err := os.ReadFile(filepath.Join(outDir, "judge-altitude.txt"))
	if err != nil || !strings.Contains(string(reply), "VERDICT: PASS") {
		t.Errorf("judge reply artifact = %q, %v", reply, err)
	}
}

func TestLLM_Grade_JudgeFailVerdict(t *testing.T) {
	useFakeClaude(t)
	t.Setenv("FAKE_JUDGE_VERDICT", "FAIL")
	g, err := grade.NewLLM("g", "c", "", grade.FocusLastMessage())
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	judge, err := grade.NewJudge("fake-judge")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Trace: parseTrace(t, resultEvent("x")), Judge: judge})
	if out.Passed || out.CostUSD != 0.001 {
		t.Errorf("Outcome = %+v, want FAIL at $0.001", out)
	}
}

func TestLLM_Grade_JudgeErrorFails(t *testing.T) {
	t.Setenv("PATH", t.TempDir()) // no claude binary anywhere
	g, err := grade.NewLLM("g", "c", "", grade.FocusLastMessage())
	if err != nil {
		t.Fatalf("NewLLM: %v", err)
	}
	judge, err := grade.NewJudge("fake-judge")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	out := g.Grade(context.Background(), grade.Subject{Judge: judge})
	if out.Passed || !strings.Contains(out.Detail, "judge:") {
		t.Errorf("Outcome = %+v, want a judge failure", out)
	}
}

func TestNewJudge(t *testing.T) {
	t.Parallel()
	j, err := grade.NewJudge(" claude-haiku-4-5 ")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	if j.Model() != "claude-haiku-4-5" {
		t.Errorf("Model() = %q", j.Model())
	}
	if _, err := grade.NewJudge(""); !errors.Is(err, grade.ErrEmptyModel) {
		t.Errorf("empty model error = %v, want ErrEmptyModel", err)
	}
	if _, err := (grade.Judge{}).Ask(context.Background(), "p"); !errors.Is(err, grade.ErrEmptyModel) {
		t.Errorf("zero Judge.Ask error = %v, want ErrEmptyModel", err)
	}
}

func TestJudge_Ask_RejectsNonJSONOutput(t *testing.T) {
	bin := t.TempDir()
	script := "#!/bin/bash\ncat >/dev/null\necho 'not json'\n"
	if err := os.WriteFile(filepath.Join(bin, "claude"), []byte(script), 0o755); err != nil {
		t.Fatalf("write fake: %v", err)
	}
	t.Setenv("PATH", bin)
	j, err := grade.NewJudge("m")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	if _, err := j.Ask(context.Background(), "p"); err == nil || !strings.Contains(err.Error(), "not a result object") {
		t.Errorf("Ask error = %v, want non-JSON complaint", err)
	}
}

func TestJudge_Ask_RejectsErrorResult(t *testing.T) {
	bin := t.TempDir()
	script := "#!/bin/bash\ncat >/dev/null\necho '{\"is_error\":true,\"subtype\":\"error_during_execution\",\"result\":\"boom\"}'\n"
	if err := os.WriteFile(filepath.Join(bin, "claude"), []byte(script), 0o755); err != nil {
		t.Fatalf("write fake: %v", err)
	}
	t.Setenv("PATH", bin)
	j, err := grade.NewJudge("m")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	if _, err := j.Ask(context.Background(), "p"); err == nil || !strings.Contains(err.Error(), "error_during_execution") {
		t.Errorf("Ask error = %v, want is_error complaint", err)
	}
}

func TestJudge_Ask_RejectsMissingVerdict(t *testing.T) {
	bin := t.TempDir()
	script := "#!/bin/bash\ncat >/dev/null\necho '{\"result\":\"I think it is fine.\",\"total_cost_usd\":0.002}'\n"
	if err := os.WriteFile(filepath.Join(bin, "claude"), []byte(script), 0o755); err != nil {
		t.Fatalf("write fake: %v", err)
	}
	t.Setenv("PATH", bin)
	j, err := grade.NewJudge("m")
	if err != nil {
		t.Fatalf("NewJudge: %v", err)
	}
	if _, err := j.Ask(context.Background(), "p"); !errors.Is(err, grade.ErrNoVerdict) {
		t.Errorf("Ask error = %v, want ErrNoVerdict", err)
	}
}

func TestParseVerdict_Success(t *testing.T) {
	t.Parallel()
	cases := []struct {
		reply string
		want  bool
	}{
		{reply: "reasoning\nVERDICT: PASS", want: true},
		{reply: "reasoning\nVERDICT: FAIL\n", want: false},
		{reply: "**Verdict: pass**", want: true},
		{reply: "VERDICT PASS", want: true},
		{reply: "VERDICT: PASS\nlater I changed my mind\nVERDICT: FAIL", want: false},
		{reply: "VERDICT: FAIL\n\nVERDICT: PASS\n\n", want: true},
	}
	for _, tc := range cases {
		got, err := grade.ParseVerdict(tc.reply)
		if err != nil {
			t.Errorf("ParseVerdict(%q): %v", tc.reply, err)
			continue
		}
		if got != tc.want {
			t.Errorf("ParseVerdict(%q) = %v, want %v", tc.reply, got, tc.want)
		}
	}
}

func TestParseVerdict_Error(t *testing.T) {
	t.Parallel()
	for _, reply := range []string{"", "PASS", "the verdict is that it passes", "VERDICT: MAYBE", "VERDICT: PASS because"} {
		if _, err := grade.ParseVerdict(reply); !errors.Is(err, grade.ErrNoVerdict) {
			t.Errorf("ParseVerdict(%q) error = %v, want ErrNoVerdict", reply, err)
		}
	}
}
