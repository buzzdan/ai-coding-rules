// Package render compiles core templates plus one language binding into the
// plugin tree: every output path with its bytes and executable bit. The tree
// is produced in memory so the same rendering can be written to disk or
// compared against the plugin directory.
package render

import (
	"bytes"
	"fmt"
	"io/fs"
	"text/template"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/binding"
)

// README.md documents core/ itself; every other core file is a template.
const coreReadme = "README.md"

// File is one rendered plugin file. Exec mirrors the source file's executable
// bit so hooks and gate scripts stay runnable after generation.
type File struct {
	Data []byte
	Exec bool
}

// Tree maps plugin-relative output paths to their rendered files.
type Tree map[string]File

// Render templates every core file through the binding, then adds the
// binding's passthrough files. Two mistakes are errors rather than silent
// wins: an output path claimed twice (a passthrough copy shadowing a
// template) and an override with no core file to replace.
func Render(core fs.FS, b binding.Binding) (Tree, error) {
	overrides, err := b.Overrides()
	if err != nil {
		return nil, err
	}
	r := renderer{binding: b, overrides: overrides, tree: Tree{}, seen: map[string]bool{}}
	if err := walkFiles(core, r.renderCore); err != nil {
		return nil, err
	}
	if err := walkFiles(overrides, r.checkOverrideHasCoreFile); err != nil {
		return nil, err
	}
	pt, err := b.Passthrough()
	if err != nil {
		return nil, err
	}
	if err := walkFiles(pt, r.copyPassthrough); err != nil {
		return nil, err
	}
	return r.tree, nil
}

type renderer struct {
	binding   binding.Binding
	overrides fs.FS
	tree      Tree
	seen      map[string]bool // core paths visited, to detect orphan overrides
}

func (r *renderer) renderCore(core fs.FS, path string) error {
	if path == coreReadme {
		return nil
	}
	r.seen[path] = true
	src, exec, err := r.source(core, path)
	if err != nil {
		return err
	}
	out, err := r.execute(path, string(src))
	if err != nil {
		return err
	}
	outPath, err := r.execute(path+" (name)", path)
	if err != nil {
		return err
	}
	return r.add(string(outPath), File{Data: out, Exec: exec})
}

// source picks the override when the binding has one, else the core file,
// and reports the executable bit of whichever file it read.
func (r *renderer) source(core fs.FS, path string) ([]byte, bool, error) {
	fsys := core
	if _, err := fs.Stat(r.overrides, path); err == nil {
		fsys = r.overrides
	}
	data, err := fs.ReadFile(fsys, path)
	if err != nil {
		return nil, false, fmt.Errorf("core: %w", err)
	}
	exec, err := isExecutable(fsys, path)
	return data, exec, err
}

func (r *renderer) checkOverrideHasCoreFile(_ fs.FS, path string) error {
	if !r.seen[path] {
		return fmt.Errorf("override %q has no core file to replace", path)
	}
	return nil
}

func (r *renderer) execute(name, text string) ([]byte, error) {
	funcs := template.FuncMap{"include": r.binding.Include}
	tmpl, err := template.New(name).Funcs(funcs).Parse(text)
	if err != nil {
		return nil, fmt.Errorf("template %s: %w", name, err)
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, r.binding.Profile().Vars); err != nil {
		return nil, fmt.Errorf("template %s: %w", name, err)
	}
	return buf.Bytes(), nil
}

func (r *renderer) copyPassthrough(fsys fs.FS, path string) error {
	data, err := fs.ReadFile(fsys, path)
	if err != nil {
		return fmt.Errorf("passthrough: %w", err)
	}
	exec, err := isExecutable(fsys, path)
	if err != nil {
		return err
	}
	return r.add(path, File{Data: data, Exec: exec})
}

func (r *renderer) add(path string, f File) error {
	if _, dup := r.tree[path]; dup {
		return fmt.Errorf("output %q is produced by two sources", path)
	}
	r.tree[path] = f
	return nil
}

func isExecutable(fsys fs.FS, path string) (bool, error) {
	info, err := fs.Stat(fsys, path)
	if err != nil {
		return false, fmt.Errorf("stat %s: %w", path, err)
	}
	return info.Mode()&0o111 != 0, nil
}

// walkFiles calls visit for every regular file. A root that does not exist is
// an error: rendering nothing from a missing core/ would delete the plugin.
func walkFiles(fsys fs.FS, visit func(fs.FS, string) error) error {
	err := fs.WalkDir(fsys, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		return visit(fsys, path)
	})
	if err != nil {
		return fmt.Errorf("walk: %w", err)
	}
	return nil
}
