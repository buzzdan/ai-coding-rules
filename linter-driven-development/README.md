# Linter-Driven Development (any language)

**The same engineering rules as the Go plugin, applied to whatever language your
repository is written in.**

This Claude Code plugin is built from the same core as
[`go-linter-driven-development`](../go-linter-driven-development/README.md): twelve
design rules stated once as data, thin skills that sequence design, TDD, refactoring,
testing, review and documentation, and an evidence-based review run by fresh-context
agents. What differs is how the language-shaped parts are filled: the Go plugin knows
Go; this plugin reads your repository and adjusts.

Install it for a repository in a language we do not maintain a binding for — Rust,
TypeScript, Java, C#, Ruby, shell — or as the first thing a new language gets. Where
a language-specific plugin exists (today: Go), install that one instead; its rows are
knowledge, this plugin's are detection.

## What it detects, and what it does not know

At pre-flight the plugin reads your repository's marker files — `go.mod`,
`pyproject.toml`, `package.json`, `Cargo.toml`, `pom.xml`, a `.csproj` — and confirms
the language against the source files present. From the same repository it discovers
the test command and the lint command you already run (README, CLAUDE.md, Makefile,
Taskfile, package scripts, CI), and the linter's configuration file. A repository with
several languages is worked one language at a time.

The rules, the review and the refactoring moves are language-neutral and run in full.
Each rule's canonical example shows the shape in pseudocode, and each falsifying
question says what to search for over the detected language's source files. The
model builds the search from what it sees; nothing is looked up in a table.

What this plugin cannot know is the part that is genuinely per language: that a
particular linter check is an enum in disguise, that a test belongs in an external
test package, or how one language's documentation form is written. Where a binding
would have known more, it says so instead of guessing.

## The linter phase without a binding

> Open question for the plugin owner: this section is the promise the generic plugin
> makes about its linter phase. Adjust it before release.

The plugin is named for the workflow, not for a linter it brings along. Its linter
phase is exactly as strong as your repository's own linter configuration:

- **It runs your linter, through your task.** Whatever the repository already
  invokes — `golangci-lint`, `ruff`, `eslint`, `clippy`, `checkstyle` — via the
  Taskfile, Makefile or package script that invokes it. It never installs or runs a
  linter the repository does not use.
- **It routes findings by what they are about.** The refactoring skill's routing
  table is keyed by finding family — complexity, function length, nesting,
  duplicated code, non-exhaustive switch, globals, single-implementation interfaces,
  data races — and the lint-fixer classifies each of your linter's findings by its
  message: mechanical ones are fixed, design ones are escalated to the rule that owns
  the fix.
- **An unknown finding is never silenced.** A check the table does not describe is
  escalated to the rule its message describes, and the report names the linter it
  came from. No suppression directive is ever added.
- **No linter is itself a finding.** A repository without a linter gets a 🟠 New
  Practice finding in every review report, and the review continues on the twelve
  rules alone — the hunters, the skeptic and the critic need no linter.

## Architecture: Rules as Data

```
linter-driven-development/
├── maxims.md     the uncompiled layer — named design questions above the rules
├── rules/        R1-primitive-obsession … R12-mutation-discipline   (single source of truth)
├── skills/       linter-driven-development · code-designing · refactoring ·
│                 pre-commit-review · testing · documentation   (thin directional views)
├── agents/       rule-hunter · overabstraction-skeptic · comment-critic · lint-fixer
├── commands/     ldd-analyze · autopilot · quickfix · prepare · review · status · wire-repo-brain
├── examples/     storify-leaf-type · overabstraction-cidr · dependency-rejection ·
│                 anti-if-dispatch · switch-to-polymorphism · private-comment-noise   (case law, in Go for demonstration)
└── scripts/      check-repo-brain.sh — repo-brain conformance gate with a detected language adapter
```

- **[`rules/`](rules/)** — R1–R12, each a self-contained hunter payload: Principle,
  Why, a canonical before/after shape, Design guidance, a Fix pattern, and Falsifying
  questions with what to search for.
- **[`skills/`](skills/)** — thin directional views that sequence and route into the
  rules. They never restate rule content.
- **[`agents/`](agents/)** — read-only or mechanical workers spawned in isolated
  contexts with the relevant rule pasted into the prompt.
- **[`scripts/check-repo-brain.sh`](scripts/check-repo-brain.sh)** — the
  documentation-network gate `/wire-repo-brain` installs into your repository. Its
  language adapter is chosen at run time: `go.mod` selects the Go block,
  `pyproject.toml` the Python block; with neither, the structure checks (frontmatter,
  index, reachability, drift) run and the first line of output says the code↔docs
  edges are unverified.

- **[`examples/`](examples/)** — the worked case studies the rules cite: the
  storified leaf type, the over-abstraction rejection the skeptic scores against,
  dependency rejection, the two dispatch cases, the private-comment verdicts. Their
  code is Go, for demonstration only; each opens with that note. The move and the
  reasoning hold in any language — read the Go as the shape and spell it in yours.

Not shipped here, because they are Go-specific rather than Go-illustrated: the
test-harness catalogue and the package-size hook.

## The Five-Phase Flow

The [`@linter-driven-development`](skills/linter-driven-development/SKILL.md) skill
is the meta-orchestrator:

```
1 DESIGN     @code-designing → DESIGN PLAN → user OK
1.5 PREPARE  preparatory refactoring: survey the plan's touch points,
      four autonomous gates decide, @refactoring reshapes → prep commit(s)
2 IMPLEMENT  per behavior: RED (one failing test, lowest rung) → GREEN → REFACTOR
3 FULL LINT  ONE run of your linter via the lint-fixer agent (isolated context)
      mechanical → FIXED · design → ESCALATED → @refactoring
4 REVIEW     per completed slice: @pre-commit-review spawns hunters + skeptic + critic
5 SHIP       @documentation → commit (tests and lint green, tree dirty) → ship summary
```

## Slash Commands

| Command | Purpose | Auto-Fix |
|---------|---------|----------|
| `/ldd-autopilot` | Full workflow (Phases 1–5) | ✅ Yes |
| `/ldd-quickfix [files \| --all]` | Quality-gates loop until green over the files you are working on | ✅ Yes |
| `/ldd-prepare <change> [files]` | Preparatory refactoring ahead of a planned change | ✅ Yes |
| `/ldd-analyze [files \| --all]` | Tests + lint + review, combined report | ❌ No |
| `/ldd-review [files \| --all]` | Commit-readiness check | ❌ No |
| `/ldd-status` | Show current phase + progress | N/A |
| `/wire-repo-brain [path]` | Wire the documentation network in one pass | ✅ Wiring only |

`/wire-repo-brain` carries no prefix: the documentation network it wires is a
property of the repository, not of a language, and the Go plugin offers the same
command. Installed side by side, both do the same structural work.

## Installation

```
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install linter-driven-development@ai-coding-rules
```

Verify with `/plugin list`; it should show `linter-driven-development (enabled)`.

## How Auto-Detection Works

When you request code work ("implement feature X", "fix the bug in the handler")
in a repository with no language-specific linter-driven-development plugin
installed, Claude detects that the skill applies and asks for permission. Select
"don't ask again for this skill in this directory" on first use.

**Triggers auto-detection:** action verbs (`implement`, `fix`, `build`, `add`,
`refactor`, `update`, `change`, `modify`), a mention of "ldd" or "@ldd", or a
`/ldd-*` command.

## Updating and uninstalling

```
/plugin update linter-driven-development@ai-coding-rules
```

See [CHANGELOG.md](CHANGELOG.md) for what changed between versions. To uninstall,
run `/plugin`, select "linter-driven-development" and choose "Uninstall".

## Need Help or Want to Contribute?

Full details, the generator that renders this plugin from its core, and the Go
plugin it shares that core with: the [main repository](https://github.com/buzzdan/ai-coding-rules).
Found a bug or have an idea? [Open an issue](https://github.com/buzzdan/ai-coding-rules/issues).

## License

MIT
