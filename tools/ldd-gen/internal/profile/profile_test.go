package profile_test

import (
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
	assert.Equal(t, []string{"evals/*", ".DS_Store"}, p.Ignore)
}

func TestParse_Errors(t *testing.T) {
	t.Parallel()
	withPlugin := func(name string) string {
		return "plugin: " + name + full[len("plugin: go-linter-driven-development"):]
	}
	cases := []struct {
		name  string
		input string
		want  string
	}{
		{name: "missing scalar", input: "plugin: x\nlang: Go\n", want: "missing cmd_prefix"},
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
