// Package gen ties the generator to one repository checkout: it finds core/
// and lang/<lang>/, renders each binding, and either writes the plugin
// directory or reports how the directory on disk differs from the rendering.
package gen

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/binding"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/check"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/profile"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/render"
	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/residue"
)

const (
	coreDir    = "core"
	langDir    = "lang"
	coreReadme = "core/README.md"
	// pluginManifest marks a Claude Code plugin directory. Generate refuses to
	// write anywhere that lacks it, since writing deletes unowned files.
	pluginManifest = ".claude-plugin/plugin.json"
)

// Repo is a checkout of this repository, addressed by its root.
type Repo struct {
	root string
}

// Open validates that root holds both core/ and lang/. Without core/ a
// rendering would be empty and writing it would delete every templated file,
// so a root missing either directory is refused up front.
func Open(root string) (Repo, error) {
	for _, dir := range []string{coreDir, langDir} {
		if err := requireDir(filepath.Join(root, dir)); err != nil {
			return Repo{}, err
		}
	}
	return Repo{root: root}, nil
}

func requireDir(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("open: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("open: %s is not a directory", path)
	}
	return nil
}

// Langs lists every binding directory under lang/, sorted.
func (r Repo) Langs() ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(r.root, langDir))
	if err != nil {
		return nil, fmt.Errorf("langs: %w", err)
	}
	var langs []string
	for _, e := range entries {
		if e.IsDir() {
			langs = append(langs, e.Name())
		}
	}
	sort.Strings(langs)
	return langs, nil
}

// Render compiles core/ with one binding and returns the tree together with
// the binding's profile, which names the output directory.
func (r Repo) Render(lang string) (render.Tree, profile.Profile, error) {
	out, err := r.render(lang)
	return out.tree, out.profile, err
}

// rendering is everything one binding produces: the plugin tree and, when the
// profile names a handbook path, the handbook document.
type rendering struct {
	tree     render.Tree
	handbook []byte
	profile  profile.Profile
}

func (r Repo) render(lang string) (rendering, error) {
	dir := filepath.Join(langDir, lang)
	b, err := r.loadBinding(lang)
	if err != nil {
		return rendering{}, err
	}
	core := os.DirFS(filepath.Join(r.root, coreDir))
	tree, err := render.Render(core, b)
	if err != nil {
		return rendering{}, fmt.Errorf("%s: %w", dir, err)
	}
	out := rendering{tree: tree, profile: b.Profile()}
	if !out.profile.HasHandbook() {
		return out, nil
	}
	out.handbook, err = render.Handbook(core, b)
	if err != nil {
		return rendering{}, fmt.Errorf("%s: %w", dir, err)
	}
	if err := requireNoGoResidue(out.profile, out.handbook); err != nil {
		return rendering{}, fmt.Errorf("%s: %w", dir, err)
	}
	return out, nil
}

// goLang is the binding whose handbook may spell Go: the residue scanner names
// Go idioms, so the Go handbook is the one it cannot judge.
const goLang = "Go"

// requireNoGoResidue fails the rendering of a handbook for any language other
// than Go that still carries a Go spelling. In the plugin a Principle sits
// beside a same-language example that softens such a sentence; the handbook
// renders it alone, so a hit is a core sentence that wants a neutral rewrite.
func requireNoGoResidue(p profile.Profile, handbook []byte) error {
	if p.Lang == goLang {
		return nil
	}
	hits := residue.ScanHandbook(p.Handbook, string(handbook))
	if len(hits) == 0 {
		return nil
	}
	var b strings.Builder
	fmt.Fprintf(&b, "handbook %s carries Go residue; reword the core sentence or the binding's include:", p.Handbook)
	for _, h := range hits {
		fmt.Fprintf(&b, "\n  %s:%d [%s] %s", h.Path, h.Line, h.Token, h.Text)
	}
	return errors.New(b.String())
}

// loadBinding reads lang/<lang>/ and, when its profile names an
// include_fallback, the binding that fallback points at. The fallback must be
// another binding directory and must not itself fall back: one step keeps
// "where does this include come from" answerable by reading two profiles.
func (r Repo) loadBinding(lang string) (binding.Binding, error) {
	dir := filepath.Join(langDir, lang)
	b, err := binding.Load(os.DirFS(filepath.Join(r.root, dir)))
	if err != nil {
		return binding.Binding{}, fmt.Errorf("%s: %w", dir, err)
	}
	fallback := b.Profile().IncludeFallback
	if !fallback.Set() {
		return b, nil
	}
	if fallback.From == lang {
		return binding.Binding{}, fmt.Errorf("%s: include_fallback.from %q names the binding itself", dir, fallback.From)
	}
	fbDir := filepath.Join(langDir, fallback.From)
	fb, err := binding.Load(os.DirFS(filepath.Join(r.root, fbDir)))
	if err != nil {
		return binding.Binding{}, fmt.Errorf("%s: include_fallback.from %q: %w", dir, fallback.From, err)
	}
	if chained := fb.Profile().IncludeFallback; chained.Set() {
		return binding.Binding{}, fmt.Errorf("%s: include_fallback.from %q itself falls back to %q; a fallback chain is not allowed", dir, fallback.From, chained.From)
	}
	return b.WithIncludeFallback(fb, fallback.Under), nil
}

// Generate renders one binding and writes it over its plugin directory.
// Writing deletes files the rendering does not own, so four checks run
// first: no two bindings may name the same plugin directory; the rendering
// must carry a plugin manifest; that manifest's name must equal the profile's
// plugin, because Skill and subagent references are built from the profile
// while Claude Code namespaces by the manifest; and a directory already on
// disk must either carry a manifest with the same name or hold nothing the
// write would touch.
func (r Repo) Generate(lang string) error {
	if err := r.requireUniquePlugins(); err != nil {
		return err
	}
	out, err := r.render(lang)
	if err != nil {
		return err
	}
	tree, p := out.tree, out.profile
	name, err := manifestName(tree[pluginManifest].Data)
	if err != nil {
		return fmt.Errorf("generate: the %s rendering: %w", lang, err)
	}
	if name != p.Plugin {
		return fmt.Errorf("generate: %s renders a manifest named %q but its profile says plugin %q; cross-plugin references would not resolve", lang, name, p.Plugin)
	}
	dir := filepath.Join(r.root, p.Plugin)
	if err := requireOwnedDir(dir, name, check.IgnoredAndUnowned(tree, p.Ignored)); err != nil {
		return err
	}
	if err := r.requireHandbookTarget(p); err != nil {
		return err
	}
	if err := check.Write(tree, dir, p.Ignored); err != nil {
		return err
	}
	return r.writeHandbook(out)
}

// requireHandbookTarget runs before anything is written: a file already at
// the handbook path must itself be a generated handbook — it opens with the
// generator's marker — so a hand-written document there is refused while the
// plugin directory is still untouched, never after a partial write.
func (r Repo) requireHandbookTarget(p profile.Profile) error {
	if !p.HasHandbook() {
		return nil
	}
	existing, err := os.ReadFile(r.handbookPath(p))
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return nil
	case err != nil:
		return fmt.Errorf("generate: handbook: %w", err)
	case !strings.HasPrefix(string(existing), render.HandbookMarker):
		return fmt.Errorf("generate: %s exists and is not a generated handbook; refusing to overwrite it", p.Handbook)
	}
	return nil
}

func (r Repo) handbookPath(p profile.Profile) string {
	return filepath.Join(r.root, filepath.FromSlash(p.Handbook))
}

// writeHandbook writes the rendered handbook to the profile's handbook path
// with mode 0644. WriteFile keeps an existing file's mode, so the mode is set
// explicitly: a handbook is a document and is never executable.
func (r Repo) writeHandbook(out rendering) error {
	if !out.profile.HasHandbook() {
		return nil
	}
	target := r.handbookPath(out.profile)
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return fmt.Errorf("generate: handbook: %w", err)
	}
	if err := os.WriteFile(target, out.handbook, 0o644); err != nil {
		return fmt.Errorf("generate: handbook: %w", err)
	}
	if err := os.Chmod(target, 0o644); err != nil {
		return fmt.Errorf("generate: handbook: %w", err)
	}
	return nil
}

// requireUniquePlugins fails when two bindings render into one directory: the
// second would overwrite the first's plugin with its own rendering. Every
// binding must load for this, so a half-written binding blocks generation
// of the others until its profile is complete.
func (r Repo) requireUniquePlugins() error {
	langs, err := r.Langs()
	if err != nil {
		return err
	}
	owner := map[string]string{}
	handbooks := map[string]string{}
	for _, lang := range langs {
		b, err := binding.Load(os.DirFS(filepath.Join(r.root, langDir, lang)))
		if err != nil {
			return fmt.Errorf("%s: %w", filepath.Join(langDir, lang), err)
		}
		p := b.Profile()
		if other, dup := owner[p.Plugin]; dup {
			return fmt.Errorf("generate: bindings %s and %s both name plugin %q", other, lang, p.Plugin)
		}
		owner[p.Plugin] = lang
		if err := claimHandbook(handbooks, lang, p.Handbook); err != nil {
			return err
		}
	}
	return requireHandbooksOutsidePlugins(handbooks, owner)
}

// claimHandbook records one binding's handbook path. Two bindings rendering
// the same document would overwrite each other's, and a path below another
// binding's handbook needs that file to be a directory, so both are refused.
func claimHandbook(handbooks map[string]string, lang, path string) error {
	if path == "" {
		return nil
	}
	for other, otherLang := range handbooks {
		if other == path || strings.HasPrefix(path, other+"/") || strings.HasPrefix(other, path+"/") {
			return fmt.Errorf("generate: bindings %s and %s both render handbook %q; %s renders %q", otherLang, lang, other, lang, path)
		}
	}
	handbooks[path] = lang
	return nil
}

// requireHandbooksOutsidePlugins keeps a handbook out of every plugin
// directory and out of the generator's own inputs, where check would count it
// as an extra file or generate would read it back as a source.
func requireHandbooksOutsidePlugins(handbooks, owner map[string]string) error {
	for path, lang := range handbooks {
		top := strings.SplitN(path, "/", 2)[0]
		if _, plugin := owner[top]; plugin || top == coreDir || top == langDir {
			return fmt.Errorf("generate: %s renders its handbook to %q, inside a directory the generator owns", lang, path)
		}
	}
	return nil
}

// manifestName reads the plugin name from a .claude-plugin/plugin.json body.
// A rendering without a named manifest is not a plugin and is never written.
func manifestName(data []byte) (string, error) {
	var m struct {
		Name string `json:"name"`
	}
	if len(data) == 0 {
		return "", fmt.Errorf("no %s", pluginManifest)
	}
	if err := json.Unmarshal(data, &m); err != nil {
		return "", fmt.Errorf("%s: %w", pluginManifest, err)
	}
	if m.Name == "" {
		return "", fmt.Errorf("%s has no name", pluginManifest)
	}
	return m.Name, nil
}

// requireOwnedDir accepts a directory whose manifest names the same plugin as
// the rendering, or one that holds nothing the write would delete or replace:
// it does not exist yet, or every file in it is ignored and unowned.
func requireOwnedDir(dir, name string, skip check.Ignore) error {
	onDisk, err := os.ReadFile(filepath.Join(dir, pluginManifest))
	if err == nil {
		return requireSameName(dir, name, onDisk)
	}
	touched, err := hasFile(dir, skip)
	if err != nil {
		return err
	}
	if touched {
		return fmt.Errorf("generate: %s is not a plugin directory (no %s); refusing to write", dir, pluginManifest)
	}
	return nil
}

func requireSameName(dir, name string, onDisk []byte) error {
	existing, err := manifestName(onDisk)
	if err != nil {
		return fmt.Errorf("generate: %s: %w", dir, err)
	}
	if existing != name {
		return fmt.Errorf("generate: %s belongs to plugin %q, the rendering is plugin %q; refusing to write", dir, existing, name)
	}
	return nil
}

func hasFile(dir string, skip check.Ignore) (bool, error) {
	found := false
	err := fs.WalkDir(os.DirFS(dir), ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if path == "." && errors.Is(err, fs.ErrNotExist) {
				return fs.SkipAll
			}
			return err
		}
		if d.IsDir() || skip(path) {
			return nil
		}
		found = true
		return fs.SkipAll
	})
	if err != nil {
		return false, fmt.Errorf("generate: %w", err)
	}
	return found, nil
}

// Check renders every binding and compares each with its plugin directory,
// writing findings to w. It returns the number of differences. A repository
// with no binding, or with two bindings for one plugin, is an error, not a
// pass.
func (r Repo) Check(w io.Writer) (int, error) {
	langs, err := r.Langs()
	if err != nil {
		return 0, err
	}
	if len(langs) == 0 {
		return 0, errors.New("check: no binding under lang/")
	}
	if err := r.requireUniquePlugins(); err != nil {
		return 0, err
	}
	total := 0
	for _, lang := range langs {
		n, err := r.checkOne(w, lang)
		if err != nil {
			return total, err
		}
		total += n
	}
	return total, nil
}

func (r Repo) checkOne(w io.Writer, lang string) (int, error) {
	out, err := r.render(lang)
	if err != nil {
		return 0, err
	}
	tree, p := out.tree, out.profile
	dir := filepath.Join(r.root, p.Plugin)
	diffs, err := check.Compare(tree, dir, p.Ignored)
	if err != nil {
		return 0, err
	}
	if len(diffs) > 0 {
		fmt.Fprintf(w, "%s: %d difference(s) between the rendering and %s/\n", lang, len(diffs), p.Plugin)
		check.Report(w, diffs, tree, dir)
	}
	n, err := r.checkHandbook(w, lang, out)
	return len(diffs) + n, err
}

// checkHandbook compares the rendered handbook with the file at its path,
// reporting a missing or changed document the way plugin files are reported.
func (r Repo) checkHandbook(w io.Writer, lang string, out rendering) (int, error) {
	if !out.profile.HasHandbook() {
		return 0, nil
	}
	rel := out.profile.Handbook
	want := render.Tree{rel: {Data: out.handbook}}
	kind, differs, err := handbookDifference(r.handbookPath(out.profile), out.handbook)
	if err != nil {
		return 0, err
	}
	var diffs []check.Difference
	if differs {
		diffs = []check.Difference{{Path: rel, Kind: kind}}
	}
	if len(diffs) > 0 {
		fmt.Fprintf(w, "%s: the handbook %s differs from its rendering\n", lang, rel)
		check.Report(w, diffs, want, r.root)
	}
	return len(diffs), nil
}

// handbookDifference compares the handbook on disk with its rendering the way
// plugin files are compared: missing, changed bytes, or an executable bit the
// rendering never sets.
func handbookDifference(target string, want []byte) (check.Kind, bool, error) {
	onDisk, err := os.ReadFile(target)
	if errors.Is(err, fs.ErrNotExist) {
		return check.Missing, true, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("check: handbook: %w", err)
	}
	if !bytes.Equal(onDisk, want) {
		return check.Changed, true, nil
	}
	info, err := os.Stat(target)
	if err != nil {
		return "", false, fmt.Errorf("check: handbook: %w", err)
	}
	if info.Mode()&0o111 != 0 {
		return check.ExecChanged, true, nil
	}
	return "", false, nil
}

// LintCore scans core/ for language residue and writes the report to w. With
// write set, the Residue section of core/README.md is rewritten from the
// report. It returns the number of hard hits; the caller fails the run when
// that is not zero.
func (r Repo) LintCore(w io.Writer, write bool) (int, error) {
	report, err := residue.Scan(os.DirFS(filepath.Join(r.root, coreDir)))
	if err != nil {
		return 0, err
	}
	fmt.Fprintln(w, strings.TrimSuffix(report.Markdown(), "\n"))
	if write {
		if err := residue.WriteReadme(filepath.Join(r.root, coreReadme), report); err != nil {
			return len(report.Hard), err
		}
	}
	return len(report.Hard), nil
}
