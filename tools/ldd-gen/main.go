// Command ldd-gen renders the linter-driven-development plugins from core/
// (language-neutral templates) and lang/<lang>/ (one binding per language),
// and checks that the committed plugin directories match that rendering.
//
// Usage:
//
//	ldd-gen -lang go        render lang/go into its plugin directory
//	ldd-gen -check          render every binding; exit 1 on any difference
//
// Both take -root <dir> (default "."), the repository root.
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

var errDifferences = errors.New("the committed plugin differs from the rendering; run `task generate` and commit the result")

func run(args []string, out io.Writer) error {
	fs := flag.NewFlagSet("ldd-gen", flag.ContinueOnError)
	fs.SetOutput(out)
	root := fs.String("root", ".", "repository root")
	lang := fs.String("lang", "", "binding under lang/ to render into its plugin directory")
	doCheck := fs.Bool("check", false, "compare every binding's rendering with its committed plugin directory")
	if err := fs.Parse(args); err != nil {
		return fmt.Errorf("flags: %w", err)
	}
	repo, err := gen.Open(*root)
	if err != nil {
		return err
	}
	switch {
	case *doCheck:
		return checkAll(repo, out)
	case *lang != "":
		return repo.Generate(*lang)
	default:
		fs.Usage()
		return errors.New("pass -lang <name> or -check")
	}
}

func checkAll(repo gen.Repo, out io.Writer) error {
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
