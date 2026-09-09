package render_test

import (
	"maps"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/binding"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/render"
)

const profileYAML = `plugin: p-plugin
lang: Lang
cmd_prefix: p-ldd
src_glob: "*.p"
test_glob: "_test.p"
project_marker: p.mod
nolint: "#nolint"
comment_prefix: "#"
default_test: ptest
default_lint: plint
default_lint_fix: plint --fix
`

func lang(t *testing.T, extra fstest.MapFS) binding.Binding {
	t.Helper()
	fsys := fstest.MapFS{
		"profile.yaml":        {Data: []byte(profileYAML)},
		"rules/R1/example.md": {Data: []byte("example body\n")},
	}
	maps.Copy(fsys, extra)
	b, err := binding.Load(fsys)
	require.NoError(t, err)
	return b
}

func TestRender_Substitutions(t *testing.T) {
	t.Parallel()
	core := fstest.MapFS{
		"README.md":                          {Data: []byte("core docs, never rendered\n")},
		"rules/R1.md":                        {Data: []byte("# R1\n\n## Example\n\n{{include \"rules/R1/example.md\"}}\n\nUse {{.SrcGlob}}.\n")},
		"commands/{{.CmdPrefix}}-analyze.md": {Data: []byte("Skill({{.Plugin}}:x)\n")},
		"scripts/gate.sh":                    {Data: []byte("#!/bin/sh\n"), Mode: 0o755},
	}
	tree, err := render.Render(core, lang(t, nil))
	require.NoError(t, err)

	assert.NotContains(t, tree, "README.md")
	assert.Equal(t, "# R1\n\n## Example\n\nexample body\n\nUse *.p.\n", string(tree["rules/R1.md"].Data))
	assert.Equal(t, "Skill(p-plugin:x)\n", string(tree["commands/p-ldd-analyze.md"].Data))
	assert.True(t, tree["scripts/gate.sh"].Exec)
	assert.False(t, tree["rules/R1.md"].Exec)
}

func TestRender_Override(t *testing.T) {
	t.Parallel()
	core := fstest.MapFS{
		"rules/R6.md":     {Data: []byte("core text\n")},
		"scripts/gate.sh": {Data: []byte("#!/bin/sh\n"), Mode: 0o755},
	}
	b := lang(t, fstest.MapFS{
		"overrides/rules/R6.md":     {Data: []byte("{{.Lang}} text\n")},
		"overrides/scripts/gate.sh": {Data: []byte("#!/bin/sh\necho override\n")},
	})
	tree, err := render.Render(core, b)
	require.NoError(t, err)
	assert.Equal(t, "Lang text\n", string(tree["rules/R6.md"].Data))
	assert.Equal(t, "#!/bin/sh\necho override\n", string(tree["scripts/gate.sh"].Data))
	assert.False(t, tree["scripts/gate.sh"].Exec, "the override's own mode wins, not the core file's")
}

func TestRender_Passthrough(t *testing.T) {
	t.Parallel()
	core := fstest.MapFS{}
	b := lang(t, fstest.MapFS{
		"passthrough/CHANGELOG.md":  {Data: []byte("{{ not a template }}\n")},
		"passthrough/hooks/hook.sh": {Data: []byte("#!/bin/sh\n"), Mode: 0o755},
	})
	tree, err := render.Render(core, b)
	require.NoError(t, err)
	assert.Equal(t, "{{ not a template }}\n", string(tree["CHANGELOG.md"].Data))
	assert.True(t, tree["hooks/hook.sh"].Exec)
}

func TestRender_EmptyCoreRendersOnlyPassthrough(t *testing.T) {
	t.Parallel()
	b := lang(t, fstest.MapFS{"passthrough/README.md": {Data: []byte("r\n")}})
	tree, err := render.Render(fstest.MapFS{}, b)
	require.NoError(t, err)
	assert.Len(t, tree, 1)
}

func TestRender_MissingCoreIsAnError(t *testing.T) {
	t.Parallel()
	missing := os.DirFS(filepath.Join(t.TempDir(), "nope"))
	_, err := render.Render(missing, lang(t, nil))
	require.Error(t, err)
}

func TestRender_Errors(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		core fstest.MapFS
		lang fstest.MapFS
		want string
	}{
		{
			name: "unknown variable",
			core: fstest.MapFS{"a.md": {Data: []byte("{{.Nope}}\n")}},
			want: "template a.md",
		},
		{
			name: "missing include",
			core: fstest.MapFS{"a.md": {Data: []byte("{{include \"rules/R9/x.md\"}}\n")}},
			want: "rules/R9/x.md",
		},
		{
			name: "passthrough shadows a template",
			core: fstest.MapFS{"a.md": {Data: []byte("x\n")}},
			lang: fstest.MapFS{"passthrough/a.md": {Data: []byte("y\n")}},
			want: "two sources",
		},
		{
			name: "bad template syntax",
			core: fstest.MapFS{"a.md": {Data: []byte("{{ include }\n")}},
			want: "template a.md",
		},
		{
			name: "override without a core file",
			core: fstest.MapFS{"a.md": {Data: []byte("x\n")}},
			lang: fstest.MapFS{"overrides/b.md": {Data: []byte("y\n")}},
			want: `override "b.md" has no core file`,
		},
		{
			name: "override of the core README is never used",
			core: fstest.MapFS{"README.md": {Data: []byte("x\n")}},
			lang: fstest.MapFS{"overrides/README.md": {Data: []byte("y\n")}},
			want: `override "README.md" has no core file`,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := render.Render(tc.core, lang(t, tc.lang))
			require.Error(t, err)
			assert.Contains(t, err.Error(), tc.want)
		})
	}
}
