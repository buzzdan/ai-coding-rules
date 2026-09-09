// Package gen ties the generator to one repository checkout: it finds core/
// and lang/<lang>/, renders each binding, and either writes the plugin
// directory or reports how the directory on disk differs from the rendering.
package gen

import (
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
	dir := filepath.Join(langDir, lang)
	b, err := binding.Load(os.DirFS(filepath.Join(r.root, dir)))
	if err != nil {
		return nil, profile.Profile{}, fmt.Errorf("%s: %w", dir, err)
	}
	tree, err := render.Render(os.DirFS(filepath.Join(r.root, coreDir)), b)
	if err != nil {
		return nil, profile.Profile{}, fmt.Errorf("%s: %w", dir, err)
	}
	return tree, b.Profile(), nil
}

// Generate renders one binding and writes it over its plugin directory.
// Writing deletes files the rendering does not own, so three checks run
// first: no two bindings may name the same plugin directory, the rendering
// must carry a plugin manifest, and a directory already on disk must either
// carry a manifest with the same plugin name or hold nothing the write would
// touch. A profile that names another plugin, or some other directory of the
// repository, is refused before anything is deleted.
func (r Repo) Generate(lang string) error {
	if err := r.requireUniquePlugins(); err != nil {
		return err
	}
	tree, p, err := r.Render(lang)
	if err != nil {
		return err
	}
	name, err := manifestName(tree[pluginManifest].Data)
	if err != nil {
		return fmt.Errorf("generate: the %s rendering: %w", lang, err)
	}
	dir := filepath.Join(r.root, p.Plugin)
	if err := requireOwnedDir(dir, name, check.IgnoredAndUnowned(tree, p.Ignored)); err != nil {
		return err
	}
	return check.Write(tree, dir, p.Ignored)
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
	for _, lang := range langs {
		b, err := binding.Load(os.DirFS(filepath.Join(r.root, langDir, lang)))
		if err != nil {
			return fmt.Errorf("%s: %w", filepath.Join(langDir, lang), err)
		}
		plugin := b.Profile().Plugin
		if other, dup := owner[plugin]; dup {
			return fmt.Errorf("generate: bindings %s and %s both name plugin %q", other, lang, plugin)
		}
		owner[plugin] = lang
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
	tree, p, err := r.Render(lang)
	if err != nil {
		return 0, err
	}
	dir := filepath.Join(r.root, p.Plugin)
	diffs, err := check.Compare(tree, dir, p.Ignored)
	if err != nil {
		return 0, err
	}
	if len(diffs) > 0 {
		fmt.Fprintf(w, "%s: %d difference(s) between the rendering and %s/\n", lang, len(diffs), p.Plugin)
		check.Report(w, diffs, tree, dir)
	}
	return len(diffs), nil
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
