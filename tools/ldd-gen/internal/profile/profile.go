// Package profile reads a language binding's profile.yaml: the scalar values
// that core templates substitute, and the output paths the generator leaves
// alone because something else owns them at run time.
package profile

import (
	"bytes"
	"errors"
	"fmt"
	"path"
	"reflect"
	"strings"

	"gopkg.in/yaml.v3"
)

// Vars holds every scalar a core template may reference as {{.Name}}. Each
// field is required; an empty one means the binding forgot to say how the
// language spells that concept, so parsing fails instead of rendering blanks.
type Vars struct {
	Plugin         string `yaml:"plugin"`
	Lang           string `yaml:"lang"`
	CmdPrefix      string `yaml:"cmd_prefix"`
	SrcGlob        string `yaml:"src_glob"`
	TestGlob       string `yaml:"test_glob"`
	ProjectMarker  string `yaml:"project_marker"`
	Nolint         string `yaml:"nolint"`
	CommentPrefix  string `yaml:"comment_prefix"`
	DefaultTest    string `yaml:"default_test"`
	DefaultLint    string `yaml:"default_lint"`
	DefaultLintFix string `yaml:"default_lint_fix"`
}

// Profile is a parsed profile.yaml. Plugin doubles as the output directory
// name, so one binding always renders into exactly one plugin directory.
type Profile struct {
	Vars   `yaml:",inline"`
	Ignore []string `yaml:"ignore"`
}

// Parse decodes profile.yaml strictly: unknown keys, empty scalars, a plugin
// name that is not a plain directory name, and malformed ignore patterns are
// errors. The generator deletes files under the plugin directory that it
// does not own, so a profile that could point it at the wrong place, or
// switch its ignore list off, must not load.
func Parse(data []byte) (Profile, error) {
	var p Profile
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	if err := dec.Decode(&p); err != nil {
		return Profile{}, fmt.Errorf("profile: %w", err)
	}
	if err := p.validate(); err != nil {
		return Profile{}, err
	}
	return p, nil
}

func (p Profile) validate() error {
	if err := p.Vars.validate(); err != nil {
		return err
	}
	if !isPlainName(p.Plugin) {
		return fmt.Errorf("profile: plugin %q must be a plain directory name", p.Plugin)
	}
	for _, pattern := range p.Ignore {
		if _, err := path.Match(pattern, ""); err != nil {
			return fmt.Errorf("profile: ignore pattern %q: %w", pattern, err)
		}
	}
	return nil
}

// isPlainName accepts one directory name: no separators, not "." or "..",
// and not hidden. The generator deletes inside this directory, so a value
// like "/" or "../x" must never reach it.
func isPlainName(name string) bool {
	return name != "" && !strings.ContainsAny(name, `/\`) && name != "." && name != ".." && !strings.HasPrefix(name, ".")
}

func (v Vars) validate() error {
	rv := reflect.ValueOf(v)
	rt := rv.Type()
	var missing []string
	for i := range rt.NumField() {
		if rv.Field(i).String() == "" {
			missing = append(missing, rt.Field(i).Tag.Get("yaml"))
		}
	}
	if len(missing) > 0 {
		return errors.New("profile: missing " + strings.Join(missing, ", "))
	}
	return nil
}

// Ignored reports whether an output path that the generator did not produce
// is tolerated. A pattern with a slash matches the path itself or any of its
// parent directories, so "evals/*" covers everything below evals/cases/. A
// pattern without a slash matches a single name anywhere, so ".DS_Store"
// covers that file in every directory.
func (p Profile) Ignored(rel string) bool {
	for _, pattern := range p.Ignore {
		if matches(pattern, rel) {
			return true
		}
	}
	return false
}

func matches(pattern, rel string) bool {
	byName := !strings.Contains(pattern, "/")
	for prefix := rel; prefix != "." && prefix != "/"; prefix = path.Dir(prefix) {
		candidate := prefix
		if byName {
			candidate = path.Base(prefix)
		}
		// Parse validated every pattern, so Match cannot fail here.
		if ok, _ := path.Match(pattern, candidate); ok {
			return true
		}
	}
	return false
}
