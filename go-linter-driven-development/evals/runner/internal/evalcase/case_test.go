package evalcase_test

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"example.com/ldd-eval/internal/evalcase"
	"example.com/ldd-eval/internal/grade"
)

const suiteDir = "../../testdata/suite"

func absSuite(t *testing.T) string {
	t.Helper()
	abs, err := filepath.Abs(suiteDir)
	if err != nil {
		t.Fatalf("abs: %v", err)
	}
	return abs
}

// scratchEvals builds a throwaway evals dir with an executable default
// scaffold and one case dir populated from files (path relative to the case).
func scratchEvals(t *testing.T, files map[string]string) (evalsDir, caseDir string) {
	t.Helper()
	evalsDir = t.TempDir()
	if err := os.MkdirAll(filepath.Join(evalsDir, "scaffold"), 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(evalsDir, "scaffold", "default.sh"), []byte("#!/usr/bin/env bash\nmkdir -p \"$1\"\n"), 0o755); err != nil {
		t.Fatalf("write scaffold: %v", err)
	}
	caseDir = filepath.Join(evalsDir, "scratch")
	for rel, content := range files {
		path := filepath.Join(caseDir, rel)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatalf("mkdir: %v", err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatalf("write %s: %v", rel, err)
		}
	}
	return evalsDir, caseDir
}

const minimalPrompt = "---\nname: scratch\n---\nDo the thing.\n"

const regexGrader = "---\ntype: regex\npattern: 'x'\n---\n"

func TestDiscover_Success(t *testing.T) {
	t.Parallel()
	cases, err := evalcase.Discover(suiteDir)
	if err != nil {
		t.Fatalf("Discover: %v", err)
	}
	if len(cases) != 2 || cases[0].Name != "minimal" || cases[1].Name != "two-tools" {
		names := make([]string, 0, len(cases))
		for _, c := range cases {
			names = append(names, c.Name)
		}
		t.Fatalf("Discover names = %v, want [minimal two-tools]", names)
	}
}

func TestDiscover_Error(t *testing.T) {
	t.Parallel()
	evalsDir, _ := scratchEvals(t, map[string]string{"prompt.md": "no frontmatter here\n"})
	if _, err := evalcase.Discover(evalsDir); err == nil {
		t.Fatal("Discover with a broken case: want error")
	}
}

func TestDiscoverLenient_ReportsBrokenAndKeepsTheRest(t *testing.T) {
	t.Parallel()
	evalsDir, _ := scratchEvals(t, map[string]string{"prompt.md": minimalPrompt, "graders/g.md": regexGrader})
	brokenDir := filepath.Join(evalsDir, "half-written")
	if err := os.MkdirAll(brokenDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(brokenDir, "prompt.md"), []byte("no frontmatter here\n"), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}
	cases, broken, err := evalcase.DiscoverLenient(evalsDir)
	if err != nil {
		t.Fatalf("DiscoverLenient: %v", err)
	}
	if len(cases) != 1 || cases[0].Name != "scratch" {
		t.Errorf("cases = %+v, want the one good case", cases)
	}
	if len(broken) != 1 || broken[0].Dir != "half-written" || broken[0].Err == nil {
		t.Errorf("broken = %+v, want the half-written dir with its error", broken)
	}
}

func TestDiscover_MalformedEvalsPath(t *testing.T) {
	t.Parallel()
	evalsDir := filepath.Join(t.TempDir(), "[")
	if err := os.MkdirAll(evalsDir, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if _, err := evalcase.Discover(evalsDir); err == nil {
		t.Fatal("Discover with a glob-hostile path: want error")
	}
}

func TestLoad_CaseYAMLUnreadable(t *testing.T) {
	t.Parallel()
	_, caseDir := scratchEvals(t, map[string]string{"prompt.md": minimalPrompt, "graders/g.md": regexGrader})
	if err := os.Mkdir(filepath.Join(caseDir, "case.yaml"), 0o755); err != nil {
		t.Fatalf("mkdir case.yaml: %v", err)
	}
	if _, err := evalcase.Load(caseDir); err == nil || !strings.Contains(err.Error(), "case.yaml") {
		t.Fatalf("Load with case.yaml as a directory: error = %v, want a case.yaml read error", err)
	}
}

func TestLoad_FullCase(t *testing.T) {
	t.Parallel()
	c, err := evalcase.Load(filepath.Join(suiteDir, "two-tools"))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	suite := absSuite(t)
	if c.Name != "two-tools" || c.Dir != filepath.Join(suite, "two-tools") || c.Prompt != "/go-ldd-review" {
		t.Errorf("identity = %q %q %q", c.Name, c.Dir, c.Prompt)
	}
	if strings.Join(c.Tags, ",") != "cheap,review" || c.Runs != 1 || c.MaxTurns != 5 || c.Timeout != 60*time.Second {
		t.Errorf("frontmatter = tags %v runs %d turns %d timeout %v", c.Tags, c.Runs, c.MaxTurns, c.Timeout)
	}
	if strings.Join(c.AllowedTools, ",") != "Bash,Read,Write,Skill" || c.AppendSystemPrompt != "Be brief.\n" || c.Model != "" {
		t.Errorf("tools/system prompt/model = %v %q %q", c.AllowedTools, c.AppendSystemPrompt, c.Model)
	}
	if c.ScaffoldScript != filepath.Join(suite, "scaffold", "default.sh") || c.Postcheck != filepath.Join(suite, "two-tools", "postcheck.sh") {
		t.Errorf("scripts = %q %q", c.ScaffoldScript, c.Postcheck)
	}
	if c.Tier != "cheap" || !strings.Contains(c.Notes, "every grader type") {
		t.Errorf("tier/notes = %q %q", c.Tier, c.Notes)
	}
	assertGraders(t, c.Graders, map[string]string{
		"bash-used": "tool_used", "evidence": "regex", "hello-exists": "file_exists", "judge": "llm",
		"no-agent": "tool_used", "no-panic": "regex", "package-lines": "regex",
		"skill-before-write": "tool_order", "trace-mentions-skill": "regex", "postcheck": "postcheck",
	})
}

func assertGraders(t *testing.T, graders []grade.Grader, want map[string]string) {
	t.Helper()
	if len(graders) != len(want) {
		t.Fatalf("graders len = %d, want %d", len(graders), len(want))
	}
	for _, g := range graders {
		if want[g.Name()] != g.Type() {
			t.Errorf("grader %s type = %s, want %s", g.Name(), g.Type(), want[g.Name()])
		}
	}
	if graders[len(graders)-1].Name() != "postcheck" {
		t.Error("postcheck must be the last grader")
	}
	if !sortedByName(graders[:len(graders)-1]) {
		t.Error("file graders must be sorted by name")
	}
}

func sortedByName(graders []grade.Grader) bool {
	for i := 1; i < len(graders); i++ {
		if graders[i-1].Name() > graders[i].Name() {
			return false
		}
	}
	return true
}

func TestLoad_Defaults(t *testing.T) {
	t.Parallel()
	c, err := evalcase.Load(filepath.Join(suiteDir, "minimal"))
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Name != "minimal" {
		t.Errorf("Name = %q, want the dir name", c.Name)
	}
	if c.Runs != 3 || c.MaxTurns != 10 || c.Timeout != 300*time.Second {
		t.Errorf("defaults = runs %d turns %d timeout %v, want 3/10/300s", c.Runs, c.MaxTurns, c.Timeout)
	}
	if c.ScaffoldScript != filepath.Join(absSuite(t), "scaffold", "default.sh") {
		t.Errorf("ScaffoldScript = %q, want the evals default", c.ScaffoldScript)
	}
	if c.Postcheck != "" || c.Tier != "" || len(c.Graders) != 1 {
		t.Errorf("optional fields = %q %q %d graders", c.Postcheck, c.Tier, len(c.Graders))
	}
	if !c.HasTag("medium") || c.HasTag("cheap") {
		t.Error("HasTag mismatch")
	}
}

func TestCase_MatchesGlob(t *testing.T) {
	t.Parallel()
	c := evalcase.Case{Name: "review-full"}
	for glob, want := range map[string]bool{"review-*": true, "review-full": true, "refactor-*": false, "*": true} {
		got, err := c.MatchesGlob(glob)
		if err != nil {
			t.Fatalf("MatchesGlob(%q): %v", glob, err)
		}
		if got != want {
			t.Errorf("MatchesGlob(%q) = %v, want %v", glob, got, want)
		}
	}
	if _, err := c.MatchesGlob("["); err == nil {
		t.Error("MatchesGlob with a malformed glob: want error")
	}
}

func TestLoad_CaseYAMLAbsolutePathsAndPostcheckOnly(t *testing.T) {
	t.Parallel()
	evalsDir, caseDir := scratchEvals(t, map[string]string{"prompt.md": minimalPrompt})
	pc := filepath.Join(evalsDir, "pc.sh")
	if err := os.WriteFile(pc, []byte("#!/usr/bin/env bash\ntrue\n"), 0o755); err != nil {
		t.Fatalf("write postcheck: %v", err)
	}
	scaffold := filepath.Join(evalsDir, "scaffold", "default.sh")
	yaml := "context:\n  scaffold_script: " + scaffold + "\npostcheck: " + pc + "\ntier: medium\n"
	if err := os.WriteFile(filepath.Join(caseDir, "case.yaml"), []byte(yaml), 0o644); err != nil {
		t.Fatalf("write case.yaml: %v", err)
	}
	c, err := evalcase.Load(caseDir)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.ScaffoldScript != scaffold || c.Postcheck != pc || c.Tier != "medium" {
		t.Errorf("case.yaml fields = %q %q %q", c.ScaffoldScript, c.Postcheck, c.Tier)
	}
	if len(c.Graders) != 1 || c.Graders[0].Type() != "postcheck" {
		t.Errorf("a postcheck-only case must have exactly the postcheck grader, got %d", len(c.Graders))
	}
}

func TestLoad_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		files   map[string]string
		wantErr error
	}{
		{name: "missing prompt", files: map[string]string{"graders/g.md": regexGrader}},
		{name: "no frontmatter", files: map[string]string{"prompt.md": "just a prompt\n"}},
		{name: "unknown frontmatter key", files: map[string]string{"prompt.md": "---\nunknown_key: x\n---\nbody\n"}},
		{name: "empty body", files: map[string]string{"prompt.md": "---\nname: x\n---\n\n"}, wantErr: evalcase.ErrEmptyPrompt},
		{name: "zero runs", files: map[string]string{"prompt.md": "---\nruns: 0\n---\nbody\n"}, wantErr: evalcase.ErrBadValue},
		{name: "negative timeout", files: map[string]string{"prompt.md": "---\ntimeout_seconds: -1\n---\nbody\n"}, wantErr: evalcase.ErrBadValue},
		{name: "invalid case.yaml", files: map[string]string{"prompt.md": minimalPrompt, "case.yaml": "tier: [unclosed\n"}},
		{name: "missing scaffold", files: map[string]string{"prompt.md": minimalPrompt, "case.yaml": "context:\n  scaffold_script: ./nope.sh\n", "graders/g.md": regexGrader}},
		{name: "no graders", files: map[string]string{"prompt.md": minimalPrompt}, wantErr: evalcase.ErrNoGraders},
		{name: "postcheck not executable", files: map[string]string{"prompt.md": minimalPrompt, "case.yaml": "postcheck: ./pc.sh\n", "pc.sh": "true\n"}, wantErr: grade.ErrBadScript},
		{name: "bad grader", files: map[string]string{"prompt.md": minimalPrompt, "graders/g.md": "---\ntype: telepathy\n---\n"}, wantErr: evalcase.ErrBadGraderType},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, caseDir := scratchEvals(t, tc.files)
			_, err := evalcase.Load(caseDir)
			if err == nil {
				t.Fatal("Load: want error, got nil")
			}
			if tc.wantErr != nil && !errors.Is(err, tc.wantErr) {
				t.Errorf("Load error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}

func writeGrader(t *testing.T, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "probe.md")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write grader: %v", err)
	}
	return path
}

func TestLoadGrader_Success(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name     string
		content  string
		wantType string
	}{
		{name: "regex all fields", content: "---\ntype: regex\npattern: 'a'\nflags: i\nmatch: count:2\ntarget: files\n---\n", wantType: "regex"},
		{name: "tool_used defaults", content: "---\ntype: tool_used\ntool: Skill\n---\n", wantType: "tool_used"},
		{name: "tool_used must not call", content: "---\ntype: tool_used\ntool: Agent\nmin: 0\nmax: 0\n---\n", wantType: "tool_used"},
		{name: "tool_order", content: "---\ntype: tool_order\nbefore: { tool: Skill, input_match: 'x' }\nafter: { tool: Write }\n---\n", wantType: "tool_order"},
		{name: "file_exists", content: "---\ntype: file_exists\npath: 'snapshot/*.go'\n---\n", wantType: "file_exists"},
		{name: "llm default focus", content: "---\ntype: llm\ncriteria: c\n---\nrubric\n", wantType: "llm"},
		{name: "llm scalar focus", content: "---\ntype: llm\ncriteria: c\nfocus: last_message\n---\n", wantType: "llm"},
		{name: "llm file focus", content: "---\ntype: llm\ncriteria: c\nfocus: { source: file, path: services/heartbeat.go }\n---\n", wantType: "llm"},
		{name: "llm files focus", content: "---\ntype: llm\ncriteria: c\nfocus: { source: files, paths: [a/x.go, b/y.go] }\n---\n", wantType: "llm"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			g, err := evalcase.LoadGrader(writeGrader(t, tc.content))
			if err != nil {
				t.Fatalf("LoadGrader: %v", err)
			}
			if g.Name() != "probe" || g.Type() != tc.wantType {
				t.Errorf("Name/Type = %q/%q, want probe/%s", g.Name(), g.Type(), tc.wantType)
			}
		})
	}
}

func TestLoadGrader_Error(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name    string
		content string
		wantErr error
	}{
		{name: "missing file", content: ""},
		{name: "no frontmatter", content: "type: regex\n"},
		{name: "unknown key", content: "---\ntype: regex\npattern: a\nregex: b\n---\n"},
		{name: "regex bad match", content: "---\ntype: regex\npattern: a\nmatch: often\n---\n", wantErr: grade.ErrBadMatch},
		{name: "file_exists absolute", content: "---\ntype: file_exists\npath: /x\n---\n", wantErr: grade.ErrBadGlob},
		{name: "tool_used no tool", content: "---\ntype: tool_used\nmin: 1\n---\n", wantErr: grade.ErrEmptyTool},
		{name: "tool_used bad regex", content: "---\ntype: tool_used\ntool: Bash\ninput_match: '('\n---\n"},
		{name: "tool_used max below min", content: "---\ntype: tool_used\ntool: Bash\nmin: 2\nmax: 1\n---\n", wantErr: grade.ErrBadBounds},
		{name: "tool_order missing after", content: "---\ntype: tool_order\nbefore: { tool: Skill }\n---\n", wantErr: grade.ErrEmptyTool},
		{name: "tool_order bad before", content: "---\ntype: tool_order\nbefore: { tool: Skill, input_match: '(' }\nafter: { tool: Write }\n---\n"},
		{name: "tool_order bad after", content: "---\ntype: tool_order\nbefore: { tool: Skill }\nafter: { tool: Write, input_match: '(' }\n---\n"},
		{name: "llm no criteria", content: "---\ntype: llm\n---\nrubric\n", wantErr: grade.ErrEmptyCriteria},
		{name: "llm bad scalar focus", content: "---\ntype: llm\ncriteria: c\nfocus: stdout\n---\n", wantErr: grade.ErrBadFocus},
		{name: "llm bad source", content: "---\ntype: llm\ncriteria: c\nfocus: { source: url, path: x }\n---\n", wantErr: grade.ErrBadFocus},
		{name: "llm file focus absolute", content: "---\ntype: llm\ncriteria: c\nfocus: { source: file, path: /x }\n---\n", wantErr: grade.ErrBadFocus},
		{name: "llm files focus empty", content: "---\ntype: llm\ncriteria: c\nfocus: { source: files, paths: [] }\n---\n", wantErr: grade.ErrBadFocus},
		{name: "llm sequence focus", content: "---\ntype: llm\ncriteria: c\nfocus: [a, b]\n---\n", wantErr: grade.ErrBadFocus},
		{name: "llm mapping with unknown shape", content: "---\ntype: llm\ncriteria: c\nfocus: { source: [a] }\n---\n", wantErr: grade.ErrBadFocus},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			path := filepath.Join(t.TempDir(), "missing.md")
			if tc.content != "" {
				path = writeGrader(t, tc.content)
			}
			_, err := evalcase.LoadGrader(path)
			if err == nil {
				t.Fatal("LoadGrader: want error, got nil")
			}
			if tc.wantErr != nil && !errors.Is(err, tc.wantErr) {
				t.Errorf("LoadGrader error = %v, want %v", err, tc.wantErr)
			}
		})
	}
}
