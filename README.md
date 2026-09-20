# AI Coding Rules

A [Claude Code](https://claude.ai/code) plugin marketplace for **linter-driven development** — workflows where quality gates (tests, linters, design review) guide your design instead of slowing you down.

## What's Inside

| | Plugin | Version | For |
|---|--------|---------|-----|
| 🐹 | [`go-linter-driven-development`](go-linter-driven-development/README.md) | 2.13.0 | Go |
| 🐍 | [`python-linter-driven-development`](python-linter-driven-development/README.md) | 0.2.0 | Python |
| 🧩 | [`linter-driven-development`](linter-driven-development/README.md) | 0.1.0 | Any language without a binding — detects the language at run time |
| ⚛️ | [`ts-react-linter-driven-development`](ts-react-linter-driven-development/README.md) | 1.2.0 | TypeScript + React |

Plus the coding rules as a single document, for a project that does not use the plugin:

- [`coding-rules/go.md`](coding-rules/go.md) — the Go coding rules: the twelve rules with Go examples, the shared house rules H1–H2 and the Go house rules G1–G6, a self-review checklist and the mechanics.
- [`coding-rules/python.md`](coding-rules/python.md) — the same twelve rules with Python examples and the Python binding's positions, the shared house rules and the Python house rules P1–P5, a self-review checklist and the mechanics.
- [`coding-rules/generic.md`](coding-rules/generic.md) — the same twelve rules for any other language: pseudocode examples, each with a note on how the language spells it, the shared house rules and the two any-language house rules A1–A2, a self-review checklist and the mechanics.

All three are generated from the same sources as the plugins, so they never drift from them; import one from your `CLAUDE.md` or `AGENTS.md`, or read it before your first PR. How they are built: [docs/handbook.md](docs/handbook.md).

And the hand-written rule documents the TS/React plugin grew out of:

- [`coding_rules_ts_react.md`](coding_rules_ts_react.md) — TypeScript + React principles
- [`testing_rules_ts_react.md`](testing_rules_ts_react.md) — TypeScript + React testing strategy (Vitest, RTL, MSW)

### Go plugin (v2 — rules as data)

The organising idea: **the rule is the unit, not the phase.** Each design principle lives exactly once, as data:

- **`rules/` R1–R12** — single source of truth: primitive obsession, self-validating types, storifying, helper placement, vertical slices, test-only interfaces, test placement, no globals, repo-brain documentation, concurrency safety, conditional dispatch (Anti-IF), mutation discipline (Fowler's Mutable Data).
- **`skills/`** — six thin directional views that sequence and route into the rules (orchestrator, design, testing, refactoring, review, documentation).
- **`agents/`** — payload-fed isolated workers: parallel single-obsession `rule-hunter`s, an `overabstraction-skeptic` that tries to kill proposed extractions, a `comment-critic` that makes every comment prove it earns its lines (Comment Value Toolbox), and a `lint-fixer` that keeps the lint loop out of your conversation.
- **`commands/`** — `/go-ldd-autopilot`, `/go-ldd-quickfix`, `/go-ldd-prepare`, `/go-ldd-analyze`, `/go-ldd-review`, `/go-ldd-status`, `/wire-repo-brain`.

Full architecture, workflow, and usage: [plugin README](go-linter-driven-development/README.md) · what changed between versions: [CHANGELOG](go-linter-driven-development/CHANGELOG.md).

### Python plugin

The same core rendered with Python knowledge: every canonical example is Python, every detection command greps `.py` files, the linter routing is keyed by ruff codes and mypy, and the testing skill speaks pytest. Where a Go idiom has no Python twin the plugin takes a position — `None` as declared absence, Null Object constants, frozen dataclasses, `match` closed by `assert_never`, `Event.wait` over `time.sleep` — recorded in [docs/language-residue.md](docs/language-residue.md). Details and the opinionated stances: [plugin README](python-linter-driven-development/README.md).

### Generic plugin

The same core rendered for repositories without a language binding. It detects the language from the repository's marker file, runs the linter the repository already configures, and routes findings by what they are about; the rules, review and refactoring moves run in full. Details and what it does not know: [plugin README](linter-driven-development/README.md).

### TS/React plugin

Six skills mirroring the same philosophy for TypeScript + React: component design, testing (React Testing Library), ESLint/SonarJS-driven refactoring, advisory pre-commit review, and documentation. Details: [plugin README](ts-react-linter-driven-development/README.md).

## Installation

**Step 1: Add the marketplace**
```
/plugin marketplace add buzzdan/ai-coding-rules
```

**Step 2: Install a plugin**
```
/plugin install go-linter-driven-development@ai-coding-rules
/plugin install python-linter-driven-development@ai-coding-rules
/plugin install linter-driven-development@ai-coding-rules
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

**Verify:** `/plugin list` should show the plugin as `enabled`.

**Update later:**
```
/plugin update go-linter-driven-development@ai-coding-rules
```

## Team Setup

Add the marketplace to your project's `.claude/settings.json` so it's known team-wide:

```json
{
  "extraKnownMarketplaces": [
    "buzzdan/ai-coding-rules"
  ]
}
```

Team members then install with the same `/plugin install` commands above.

## Developing the Plugins

1. Clone the repo. The Go, Python and generic plugin directories are generated, and so are `coding-rules/go.md`, `coding-rules/python.md` and `coding-rules/generic.md`: edit the sources under `core/` (language-neutral text, with the neutral defaults under `core/includes/`) and `lang/go/`, `lang/python/` or `lang/generic/` (the bindings), then run `task generate`, `task generate BINDING=python` and `task generate BINDING=generic` and commit all of them. `task check` fails when a plugin directory or a handbook drifts from its sources. How the pieces fit: [core/README.md](core/README.md), [docs/generator.md](docs/generator.md) and [docs/handbook.md](docs/handbook.md).
2. Test locally by adding the checkout as a marketplace:
   ```
   /plugin marketplace add ./ai-coding-rules
   /plugin install go-linter-driven-development@ai-coding-rules
   ```
   After changes, uninstall/reinstall the plugin to pick them up.
3. For the generated plugins, follow the architecture contract — each fact lives once: rule content goes in `core/rules/`, language-neutral defaults for a binding slot in `core/includes/`, Go material in `lang/go/`, Python material in `lang/python/`, the case studies' doctrine in `core/examples/` and their code sections in `lang/<lang>/examples/`, skills only sequence and route. See the [plugin README](go-linter-driven-development/README.md#architecture-rules-as-data).
4. Behavior changes to the Go and Python plugins are measured, not eyeballed: behavioral evals run them on a deliberately bad fixture project (go-mini, py-mini) and compare against a recorded baseline. Start at [docs/index.md](docs/index.md) — the harness, the fixture, how to write a case, the runner, and how to read a baseline. The cases, fixture, runner and baselines live in [buzzdan/ldd-evals](https://github.com/buzzdan/ldd-evals); `scripts/evals.sh` runs them against this checkout.
5. Open a PR; releases are tagged per plugin (e.g. [`go-ldd-v2.0.0`](https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.0.0)).

## License

MIT
