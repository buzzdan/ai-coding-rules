// Command ldd-gen renders the linter-driven-development plugins from core/
// (language-neutral templates) and lang/<lang>/ (one binding per language),
// and checks that the plugin directories on disk match that rendering.
//
// Usage:
//
//	ldd-gen -lang go              render lang/go into its plugin directory
//	ldd-gen -check                render every binding; exit 1 on any difference
//	ldd-gen lint-core [-write]    report language residue left in core/; exit 1
//	                              on hard hits; -write refreshes core/README.md
//
// Every form takes -root <dir> (default "."), the repository root, after the
// subcommand when there is one.
package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/buzzdan/ai-coding-rules/tools/ldd-gen/internal/gen"
)

func main() {
	if err := run(os.Args[1:], os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "ldd-gen:", err)
		os.Exit(1)
	}
}

var (
	errDifferences = errors.New("a plugin directory differs from its rendering; edit core/ or lang/<lang>/, never the plugin directory, then run `task generate` and commit both")
	errHardResidue = errors.New("hard residue in core/: each hit needs a profile scalar or an include")
	errBothModes   = errors.New("-check renders every binding; do not combine it with -lang")
	errNoMode      = errors.New("pass -lang <name>, -check, or lint-core")
)

func run(args []string, out io.Writer) error {
	if len(args) > 0 && args[0] == "lint-core" {
		return lintCore(args[1:], out)
	}
	fs := flag.NewFlagSet("ldd-gen", flag.ContinueOnError)
	fs.SetOutput(out)
	root := fs.String("root", ".", "repository root")
	lang := fs.String("lang", "", "binding under lang/ to render into its plugin directory")
	doCheck := fs.Bool("check", false, "compare every binding's rendering with its plugin directory")
	if err := fs.Parse(args); err != nil {
		return fmt.Errorf("flags: %w", err)
	}
	switch {
	case *doCheck && *lang != "":
		return errBothModes
	case *doCheck:
		return checkAll(*root, out)
	case *lang != "":
		return generate(*root, *lang)
	default:
		fs.Usage()
		return errNoMode
	}
}

func generate(root, lang string) error {
	repo, err := gen.Open(root)
	if err != nil {
		return err
	}
	return repo.Generate(lang)
}

func checkAll(root string, out io.Writer) error {
	repo, err := gen.Open(root)
	if err != nil {
		return err
	}
	n, err := repo.Check(out)
	if err != nil {
		return err
	}
	if n > 0 {
		return errDifferences
	}
	fmt.Fprintln(out, "ldd-gen: every plugin directory matches its rendering")
	return nil
}

func lintCore(args []string, out io.Writer) error {
	fs := flag.NewFlagSet("ldd-gen lint-core", flag.ContinueOnError)
	fs.SetOutput(out)
	root := fs.String("root", ".", "repository root")
	write := fs.Bool("write", false, "rewrite the Residue section of core/README.md")
	if err := fs.Parse(args); err != nil {
		return fmt.Errorf("flags: %w", err)
	}
	repo, err := gen.Open(*root)
	if err != nil {
		return err
	}
	hard, err := repo.LintCore(out, *write)
	if err != nil {
		return err
	}
	if hard > 0 {
		return errHardResidue
	}
	return nil
}
