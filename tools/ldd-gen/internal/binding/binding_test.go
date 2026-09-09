package binding_test

import (
	"io/fs"
	"testing"
	"testing/fstest"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/binding"
)

const profileYAML = `plugin: p
lang: L
cmd_prefix: x
src_glob: "*.x"
test_glob: "_test.x"
project_marker: x.mod
nolint: "#nolint"
comment_prefix: "#"
default_test: xtest
default_lint: xlint
default_lint_fix: xlint --fix
`

func langFS() fstest.MapFS {
	return fstest.MapFS{
		"profile.yaml":                 {Data: []byte(profileYAML)},
		"rules/R1/example.md":          {Data: []byte("body line 1\nbody line 2\n")},
		"rules/R1/two-newlines.md":     {Data: []byte("body\n\n")},
		"overrides/rules/R6.md":        {Data: []byte("replaced\n")},
		"passthrough/README.md":        {Data: []byte("readme\n")},
		"passthrough/hooks/hook.sh":    {Data: []byte("#!/bin/sh\n"), Mode: 0o755},
		"passthrough/.claude-plugin/p": {Data: []byte("{}\n")},
	}
}

func TestLoad(t *testing.T) {
	t.Parallel()
	b, err := binding.Load(langFS())
	require.NoError(t, err)
	assert.Equal(t, "p", b.Profile().Plugin)
}

func TestLoad_NoProfile(t *testing.T) {
	t.Parallel()
	_, err := binding.Load(fstest.MapFS{})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "profile.yaml")
}

func TestInclude(t *testing.T) {
	t.Parallel()
	b, err := binding.Load(langFS())
	require.NoError(t, err)
	cases := []struct {
		name string
		file string
		want string
	}{
		{name: "trims exactly one trailing newline", file: "rules/R1/example.md", want: "body line 1\nbody line 2"},
		{name: "keeps the second newline", file: "rules/R1/two-newlines.md", want: "body\n"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			got, err := b.Include(tc.file)
			require.NoError(t, err)
			assert.Equal(t, tc.want, got)
		})
	}
}

func TestInclude_Missing(t *testing.T) {
	t.Parallel()
	b, err := binding.Load(langFS())
	require.NoError(t, err)
	_, err = b.Include("rules/R9/nope.md")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "rules/R9/nope.md")
}

func TestOverride(t *testing.T) {
	t.Parallel()
	b, err := binding.Load(langFS())
	require.NoError(t, err)

	data, ok, err := b.Override("rules/R6.md")
	require.NoError(t, err)
	assert.True(t, ok)
	assert.Equal(t, "replaced\n", string(data))

	_, ok, err = b.Override("rules/R1.md")
	require.NoError(t, err)
	assert.False(t, ok)
}

func TestPassthrough(t *testing.T) {
	t.Parallel()
	b, err := binding.Load(langFS())
	require.NoError(t, err)
	pt, err := b.Passthrough()
	require.NoError(t, err)
	data, err := fs.ReadFile(pt, "hooks/hook.sh")
	require.NoError(t, err)
	assert.Equal(t, "#!/bin/sh\n", string(data))
	info, err := fs.Stat(pt, "hooks/hook.sh")
	require.NoError(t, err)
	assert.NotZero(t, info.Mode()&0o111)
}

func TestPassthrough_Absent(t *testing.T) {
	t.Parallel()
	b, err := binding.Load(fstest.MapFS{"profile.yaml": {Data: []byte(profileYAML)}})
	require.NoError(t, err)
	pt, err := b.Passthrough()
	require.NoError(t, err)
	_, err = fs.ReadFile(pt, "anything")
	require.ErrorIs(t, err, fs.ErrNotExist)
}
