package gen_test

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/gen"
)

const profileYAML = `plugin: out-plugin
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
ignore: ["evals/*"]
`

func write(t *testing.T, root, rel, content string) {
	t.Helper()
	path := filepath.Join(root, rel)
	require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
}

func miniRepo(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	write(t, root, "lang/p/profile.yaml", profileYAML)
	write(t, root, "lang/p/rules/R1/example.md", "example\n")
	write(t, root, "lang/p/passthrough/CHANGELOG.md", "log\n")
	write(t, root, "core/README.md", "about core\n")
	write(t, root, "core/rules/R1.md", "{{include \"rules/R1/example.md\"}} in {{.Lang}}\n")
	return root
}

func TestOpen_NoLangDir(t *testing.T) {
	t.Parallel()
	_, err := gen.Open(t.TempDir())
	require.Error(t, err)
}

func TestGenerateThenCheck(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	repo, err := gen.Open(root)
	require.NoError(t, err)

	langs, err := repo.Langs()
	require.NoError(t, err)
	assert.Equal(t, []string{"p"}, langs)

	var out bytes.Buffer
	n, err := repo.Check(&out)
	require.NoError(t, err)
	assert.Equal(t, 2, n, "nothing generated yet: both outputs are missing")

	require.NoError(t, repo.Generate("p"))
	got, err := os.ReadFile(filepath.Join(root, "out-plugin/rules/R1.md"))
	require.NoError(t, err)
	assert.Equal(t, "example in Lang\n", string(got))

	out.Reset()
	n, err = repo.Check(&out)
	require.NoError(t, err)
	assert.Zero(t, n)
	assert.Empty(t, out.String())
}

func TestCheck_ReportsEdits(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	repo, err := gen.Open(root)
	require.NoError(t, err)
	require.NoError(t, repo.Generate("p"))
	write(t, root, "out-plugin/rules/R1.md", "hand edit\n")
	write(t, root, "out-plugin/evals/cases/x.md", "ignored\n")

	var out bytes.Buffer
	n, err := repo.Check(&out)
	require.NoError(t, err)
	assert.Equal(t, 1, n)
	assert.Contains(t, out.String(), "changed       rules/R1.md")
	assert.NotContains(t, out.String(), "evals/cases")
}

func TestRender_UnknownLang(t *testing.T) {
	t.Parallel()
	repo, err := gen.Open(miniRepo(t))
	require.NoError(t, err)
	_, _, err = repo.Render("nope")
	require.Error(t, err)
}

// TestGolden is the invariant of the whole repository: rendering the committed
// bindings reproduces the committed plugin directories exactly.
func TestGolden(t *testing.T) {
	t.Parallel()
	repo, err := gen.Open(filepath.Join("..", "..", "..", ".."))
	require.NoError(t, err)
	var out bytes.Buffer
	n, err := repo.Check(&out)
	require.NoError(t, err)
	assert.Zero(t, n, out.String())
}
