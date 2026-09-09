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
	write(t, root, "lang/p/passthrough/.claude-plugin/plugin.json", `{"name": "out-plugin"}`+"\n")
	write(t, root, "lang/README.md", "not a binding\n")
	write(t, root, "core/README.md", "about core\n\n<!-- residue:begin -->\nold\n<!-- residue:end -->\n")
	write(t, root, "core/rules/R1.md", "{{include \"rules/R1/example.md\"}} in {{.Lang}}\n")
	return root
}

func TestOpen_Errors(t *testing.T) {
	t.Parallel()
	noCore := t.TempDir()
	write(t, noCore, "lang/p/profile.yaml", profileYAML)
	fileAsCore := t.TempDir()
	write(t, fileAsCore, "core", "a file\n")
	write(t, fileAsCore, "lang/p/profile.yaml", profileYAML)
	cases := []struct {
		name string
		root string
	}{
		{name: "empty root", root: t.TempDir()},
		{name: "lang without core", root: noCore},
		{name: "core is a file", root: fileAsCore},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, err := gen.Open(tc.root)
			require.Error(t, err)
		})
	}
}

func TestGenerateThenCheck(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	repo, err := gen.Open(root)
	require.NoError(t, err)

	langs, err := repo.Langs()
	require.NoError(t, err)
	assert.Equal(t, []string{"p"}, langs, "files under lang/ are not bindings")

	var out bytes.Buffer
	n, err := repo.Check(&out)
	require.NoError(t, err)
	assert.Equal(t, 3, n, "nothing generated yet: all outputs are missing")

	write(t, root, "out-plugin/evals/cases/x.md", "copied in by an eval run\n")
	require.NoError(t, repo.Generate("p"))
	got, err := os.ReadFile(filepath.Join(root, "out-plugin/rules/R1.md"))
	require.NoError(t, err)
	assert.Equal(t, "example in Lang\n", string(got))
	assert.FileExists(t, filepath.Join(root, "out-plugin/evals/cases/x.md"), "generate leaves ignored files alone")

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

	var out bytes.Buffer
	n, err := repo.Check(&out)
	require.NoError(t, err)
	assert.Equal(t, 1, n)
	assert.Contains(t, out.String(), "changed       rules/R1.md")
	assert.NotContains(t, out.String(), "evals/cases")
}

func TestCheck_NoBindingIsAnError(t *testing.T) {
	t.Parallel()
	root := t.TempDir()
	write(t, root, "core/README.md", "core\n")
	write(t, root, "lang/README.md", "no bindings here\n")
	repo, err := gen.Open(root)
	require.NoError(t, err)
	_, err = repo.Check(&bytes.Buffer{})
	require.Error(t, err)
}

func TestGenerate_RefusesNonPluginTargets(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	write(t, root, "out-plugin/README.md", "some unrelated directory\n")
	repo, err := gen.Open(root)
	require.NoError(t, err)
	err = repo.Generate("p")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not a plugin directory")
	assert.FileExists(t, filepath.Join(root, "out-plugin/README.md"), "nothing was deleted")

	noManifest := miniRepo(t)
	require.NoError(t, os.Remove(filepath.Join(noManifest, "lang/p/passthrough/.claude-plugin/plugin.json")))
	repo, err = gen.Open(noManifest)
	require.NoError(t, err)
	err = repo.Generate("p")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "no .claude-plugin/plugin.json")

	otherPlugin := miniRepo(t)
	write(t, otherPlugin, "out-plugin/.claude-plugin/plugin.json", `{"name": "someone-else"}`+"\n")
	write(t, otherPlugin, "out-plugin/README.md", "theirs\n")
	repo, err = gen.Open(otherPlugin)
	require.NoError(t, err)
	err = repo.Generate("p")
	require.Error(t, err)
	assert.Contains(t, err.Error(), `belongs to plugin "someone-else"`)
	assert.FileExists(t, filepath.Join(otherPlugin, "out-plugin/README.md"))
}

func TestGenerate_RefusesTwoBindingsForOnePlugin(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	write(t, root, "lang/q/profile.yaml", profileYAML)
	repo, err := gen.Open(root)
	require.NoError(t, err)
	err = repo.Generate("p")
	require.Error(t, err)
	assert.Contains(t, err.Error(), `both name plugin "out-plugin"`)
	_, err = repo.Check(&bytes.Buffer{})
	require.Error(t, err)
	assert.Contains(t, err.Error(), `both name plugin "out-plugin"`)
}

func TestGenerate_IgnoredOwnedFileBlocksAForeignDir(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	write(t, root, "lang/p/passthrough/evals/README.md", "pointer\n")
	write(t, root, "out-plugin/evals/README.md", "someone else's file at an owned, ignored path\n")
	repo, err := gen.Open(root)
	require.NoError(t, err)
	require.Error(t, repo.Generate("p"), "an owned path is overwritten, so it counts as touched")
}

func TestGenerate_EmptyTargetIsFine(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	require.NoError(t, os.MkdirAll(filepath.Join(root, "out-plugin"), 0o755))
	repo, err := gen.Open(root)
	require.NoError(t, err)
	require.NoError(t, repo.Generate("p"))
}

func TestRender_UnknownLang(t *testing.T) {
	t.Parallel()
	repo, err := gen.Open(miniRepo(t))
	require.NoError(t, err)
	_, _, err = repo.Render("nope")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "lang/nope")
}

func TestLintCore(t *testing.T) {
	t.Parallel()
	root := miniRepo(t)
	repo, err := gen.Open(root)
	require.NoError(t, err)

	var out bytes.Buffer
	hard, err := repo.LintCore(&out, false)
	require.NoError(t, err)
	assert.Zero(t, hard)
	readme, err := os.ReadFile(filepath.Join(root, "core/README.md"))
	require.NoError(t, err)
	assert.Contains(t, string(readme), "\nold\n", "without -write the README is untouched")

	write(t, root, "core/rules/R2.md", "run golangci-lint\n")
	out.Reset()
	hard, err = repo.LintCore(&out, true)
	require.NoError(t, err)
	assert.Equal(t, 1, hard)
	assert.Contains(t, out.String(), "rules/R2.md:1")
	readme, err = os.ReadFile(filepath.Join(root, "core/README.md"))
	require.NoError(t, err)
	assert.Contains(t, string(readme), "Hard residue (1)")
	assert.NotContains(t, string(readme), "\nold\n")
}

// Runs against the real checkout: each plugin directory must equal its
// rendering exactly.
func TestGolden(t *testing.T) {
	t.Parallel()
	repo, err := gen.Open(filepath.Join("..", "..", "..", ".."))
	require.NoError(t, err)
	var out bytes.Buffer
	n, err := repo.Check(&out)
	require.NoError(t, err)
	assert.Zero(t, n, out.String())
}
