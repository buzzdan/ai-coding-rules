package profile_test

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/profile"
)

const full = `plugin: go-linter-driven-development
lang: Go
cmd_prefix: go-ldd
src_glob: "*.go"
test_glob: "_test.go"
project_marker: go.mod
nolint: "//nolint"
comment_prefix: "//"
default_test: go test ./...
default_lint: golangci-lint run
default_lint_fix: golangci-lint run --fix
nil: nil
task: goroutine
doc_form: godoc
doc_comment: godoc comment
src_ext: .go
unexported: unexported
ignore:
  - evals/*
  - .DS_Store
`

func TestParse_Success(t *testing.T) {
	t.Parallel()
	p, err := profile.Parse([]byte(full))
	require.NoError(t, err)
	assert.Equal(t, "go-linter-driven-development", p.Plugin)
	assert.Equal(t, "go-ldd", p.CmdPrefix)
	assert.Equal(t, "golangci-lint run --fix", p.DefaultLintFix)
	assert.Equal(t, "nil", p.Nil)
	assert.Equal(t, "goroutine", p.Task)
	assert.Equal(t, "godoc", p.DocForm)
	assert.Equal(t, "godoc comment", p.DocComment)
	assert.Equal(t, ".go", p.SrcExt)
	assert.Equal(t, "unexported", p.Unexported)
	assert.Equal(t, []string{"evals/*", ".DS_Store"}, p.Ignore)
	assert.False(t, p.IncludeFallback.Set())
}

func TestParse_Handbook(t *testing.T) {
	t.Parallel()
	p, err := profile.Parse([]byte(full))
	require.NoError(t, err)
	assert.False(t, p.HasHandbook())

	p, err = profile.Parse([]byte(full + "handbook: coding-rules/go.md\n"))
	require.NoError(t, err)
	assert.True(t, p.HasHandbook())
	assert.Equal(t, "coding-rules/go.md", p.Handbook)

	for _, bad := range []string{"/abs.md", "../up.md", "a/../b.md", ".hidden.md", "notes.txt", "./go.md", "dir/"} {
		_, err := profile.Parse([]byte(full + "handbook: \"" + bad + "\"\n"))
		require.Error(t, err, bad)
		assert.Contains(t, err.Error(), "handbook", bad)
	}
}

func TestParse_IncludeFallback(t *testing.T) {
	t.Parallel()
	p, err := profile.Parse([]byte(full + "include_fallback:\n  from: go\n  under: examples/\n"))
	require.NoError(t, err)
	assert.True(t, p.IncludeFallback.Set())
	assert.Equal(t, profile.IncludeFallback{From: "go", Under: "examples/"}, p.IncludeFallback)
}

func TestParse_Errors(t *testing.T) {
	t.Parallel()
	withPlugin := func(name string) string {
		return "plugin: " + name + full[len("plugin: go-linter-driven-development"):]
	}
	withPrefix := func(prefix string) string {
		return strings.Replace(full, "cmd_prefix: go-ldd", "cmd_prefix: "+prefix, 1)
	}
	cases := []struct {
		name  string
		input string
		want  string
	}{
		{name: "missing scalar", input: "plugin: x\nlang: Go\n", want: "missing cmd_prefix"},
		{name: "missing word scalar", input: strings.Replace(full, "nil: nil\n", "", 1), want: "missing nil"},
		{name: "unknown key", input: full + "extra: 1\n", want: "field extra not found"},
		{name: "not yaml", input: "plugin: [", want: "profile:"},
		{name: "empty file", input: "", want: "profile:"},
		{name: "plugin is a path", input: withPlugin("lang/go"), want: "plain directory name"},
		{name: "plugin is dot", input: withPlugin("."), want: "plain directory name"},
		{name: "plugin is parent", input: withPlugin(".."), want: "plain directory name"},
		{name: "plugin is absolute", input: withPlugin("/tmp"), want: "plain directory name"},
		{name: "plugin is the root", input: withPlugin("/"), want: "plain directory name"},
		{name: "plugin is hidden", input: withPlugin(".git"), want: "plain directory name"},
		{name: "plugin has a backslash", input: withPlugin(`a\b`), want: "plain directory name"},
		{name: "bad ignore pattern", input: full + "  - 'evals/['\n", want: `ignore pattern "evals/["`},
		{name: "cmd_prefix escapes", input: withPrefix("../../evil"), want: "cmd_prefix"},
		{name: "cmd_prefix with slash", input: withPrefix("go/ldd"), want: "cmd_prefix"},
		{name: "cmd_prefix upper case", input: withPrefix("Go-LDD"), want: "cmd_prefix"},
		{name: "include_fallback.from is a path", input: full + "include_fallback: {from: ../go, under: examples/}\n", want: "include_fallback.from"},
		{name: "include_fallback.from is hidden", input: full + "include_fallback: {from: .go, under: examples/}\n", want: "include_fallback.from"},
		{name: "include_fallback without under", input: full + "include_fallback: {from: go}\n", want: "include_fallback.under"},
		{name: "include_fallback.under without slash", input: full + "include_fallback: {from: go, under: examples}\n", want: "include_fallback.under"},
		{name: "include_fallback.under escapes", input: full + "include_fallback: {from: go, under: ../examples/}\n", want: "include_fallback.under"},
		{name: "include_fallback.under absolute", input: full + "include_fallback: {from: go, under: /examples/}\n", want: "include_fallback.under"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := profile.Parse([]byte(tc.input))
			require.Error(t, err)
			assert.Contains(t, err.Error(), tc.want)
		})
	}
}

func TestIgnored(t *testing.T) {
	t.Parallel()
	p, err := profile.Parse([]byte(full))
	require.NoError(t, err)
	cases := []struct {
		name string
		rel  string
		want bool
	}{
		{name: "direct child", rel: "evals/cases.yaml", want: true},
		{name: "nested", rel: "evals/cases/trigger/prompt.md", want: true},
		{name: "name pattern at root", rel: ".DS_Store", want: true},
		{name: "name pattern nested", rel: "rules/.DS_Store", want: true},
		{name: "name pattern on a directory", rel: "rules/.DS_Store/x", want: true},
		{name: "produced file elsewhere", rel: "rules/R1.md", want: false},
		{name: "prefix without slash", rel: "evalsx/y.md", want: false},
		{name: "the ignored directory itself", rel: "evals", want: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			assert.Equal(t, tc.want, p.Ignored(tc.rel))
		})
	}
}

func TestIgnoredName(t *testing.T) {
	t.Parallel()
	p, err := profile.Parse([]byte(full))
	require.NoError(t, err)
	assert.True(t, p.IgnoredName(".DS_Store"))
	assert.False(t, p.IgnoredName(".mcp.json"), "hidden is not the same as ignored")
	assert.False(t, p.IgnoredName("evals"), "path patterns do not apply to bare names")
}
