// Command ldd-eval runs the go-linter-driven-development behavioral eval
// cases over headless `claude -p` and grades the traces. It mirrors the
// `claude plugin eval` case format so the cases outlive this runner.
package main

import (
	"os"

	"example.com/ldd-eval/internal/cli"
)

func main() {
	os.Exit(cli.Run(os.Args[1:], os.Stdout, os.Stderr))
}
