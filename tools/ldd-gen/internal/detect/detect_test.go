package detect_test

import (
	"strings"
	"testing"
	"testing/fstest"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/detect"
)

const good = `A preamble paragraph that belongs to no question.

1. **Does the diff validate inline?**
   Detect-grep: ` + "`" + `if .*\b[a-z]+ == ""` + "`" + ` files=src exclude-path=(^|/)cmd/ context=3
   Detection: read each hit.
   Violation: an inline check.

2. **Is the same predicate enforced twice?**
   Detect: judgment
   Detection: for each predicate found above, count hits.

3. **Is a package named after a layer?**
   Detect-path: ` + "`" + `(^|/)(services|handlers)/` + "`" + `
   Violation: any hit.

4. **Is any doc an orphan, even when the headline wraps onto a second
   line?**
   Detect-gate: Q1
   Violation: a doc no index lists.
`

func repo(files map[string]string) fstest.MapFS {
	fsys := fstest.MapFS{}
	for p, body := range files {
		fsys[p] = &fstest.MapFile{Data: []byte(body)}
	}
	return fsys
}

func TestLint_CleanFilesPass(t *testing.T) {
	t.Parallel()
	problems, err := detect.Lint(repo(map[string]string{
		"core/includes/rules/R1/falsifying-questions.md": good,
		"lang/go/rules/R1/falsifying-questions.md":       good,
	}))
	require.NoError(t, err)
	assert.Empty(t, problems)
}

func TestLint_Problems(t *testing.T) {
	t.Parallel()
	cases := []struct {
		name string
		edit func(string) string
		want string
	}{
		{"no detect line", func(s string) string { return strings.Replace(s, "   Detect: judgment\n", "", 1) }, "question 2 has no detect line"},
		{"two detect lines", func(s string) string {
			return strings.Replace(s, "   Detect: judgment\n", "   Detect: judgment\n   Detect-gate: Q2\n", 1)
		}, "question 2 has 2 detect lines"},
		{"unknown kind", func(s string) string { return strings.Replace(s, "Detect-gate: Q1", "Detect-run: Q1", 1) }, `unknown detect kind "Detect-run"`},
		{"bare detect not judgment", func(s string) string { return strings.Replace(s, "Detect: judgment", "Detect: later", 1) }, "says judgment and nothing else"},
		{"gate without Qn", func(s string) string { return strings.Replace(s, "Detect-gate: Q1", "Detect-gate: orphan", 1) }, "names the R9 gate's question as Q<n>"},
		{"pattern without backticks", func(s string) string {
			return strings.Replace(s, "Detect-path: `(^|/)(services|handlers)/`", "Detect-path: services/", 1)
		}, "needs a backticked pattern"},
		{"pattern does not compile", func(s string) string {
			return strings.Replace(s, "`(^|/)(services|handlers)/`", "`(^|/)(services|handlers/`", 1)
		}, "does not compile"},
		{"placeholder left in pattern", func(s string) string {
			return strings.Replace(s, "`(^|/)(services|handlers)/`", "`<feature>/service`", 1)
		}, "carries the placeholder <feature>"},
		{"path with flags", func(s string) string {
			return strings.Replace(s, "(services|handlers)/`", "(services|handlers)/` files=all", 1)
		}, "Detect-path takes no flags"},
		{"unknown flag", func(s string) string { return strings.Replace(s, "context=3", "after=3", 1) }, `unknown detect flag "after=3"`},
		{"bad files flag", func(s string) string { return strings.Replace(s, "files=src", "files=prod", 1) }, `unknown detect flag "files=prod"`},
		{"flag twice", func(s string) string { return strings.Replace(s, "files=src", "files=src files=all", 1) }, "flag files given twice"},
		{"numbering gap", func(s string) string { return strings.Replace(s, "3. **Is a package", "5. **Is a package", 1) }, "numbered 5 where 3 was expected"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			problems, err := detect.Lint(repo(map[string]string{
				"core/includes/rules/R1/falsifying-questions.md": tc.edit(good),
			}))
			require.NoError(t, err)
			require.Len(t, problems, 1, "%v", problems)
			assert.Contains(t, problems[0].Msg, tc.want)
			assert.Equal(t, "core/includes/rules/R1/falsifying-questions.md", problems[0].Path)
			assert.Positive(t, problems[0].Line)
		})
	}
}

func TestLint_QuestionCountsMatchAcrossBindings(t *testing.T) {
	t.Parallel()
	short := strings.SplitN(good, "\n4. ", 2)[0] + "\n"
	problems, err := detect.Lint(repo(map[string]string{
		"core/includes/rules/R1/falsifying-questions.md": good,
		"lang/go/rules/R1/falsifying-questions.md":       good,
		"lang/python/rules/R1/falsifying-questions.md":   short,
	}))
	require.NoError(t, err)
	require.Len(t, problems, 1, "%v", problems)
	assert.Equal(t, "lang/python/rules/R1/falsifying-questions.md", problems[0].Path)
	assert.Contains(t, problems[0].Msg, "R1 carries 3 questions here and 4 in core/includes/rules/R1/falsifying-questions.md")
}

func TestLint_ProblemsAreSortedByPathAndLine(t *testing.T) {
	t.Parallel()
	broken := strings.Replace(strings.Replace(good, "   Detect: judgment\n", "", 1), "Detect-gate: Q1", "Detect-gate: nope", 1)
	problems, err := detect.Lint(repo(map[string]string{
		"lang/go/rules/R1/falsifying-questions.md":       broken,
		"core/includes/rules/R1/falsifying-questions.md": broken,
	}))
	require.NoError(t, err)
	require.Len(t, problems, 4)
	assert.Equal(t, "core/includes/rules/R1/falsifying-questions.md", problems[0].Path)
	assert.Less(t, problems[0].Line, problems[1].Line)
	assert.Equal(t, "lang/go/rules/R1/falsifying-questions.md", problems[2].Path)
	assert.Equal(t, "core/includes/rules/R1/falsifying-questions.md:8: question 2 has no detect line (Detect-grep, Detect-path, Detect-gate or Detect: judgment)", problems[0].String())
}
