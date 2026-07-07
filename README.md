# AI Coding Rules

A [Claude Code](https://claude.ai/code) plugin marketplace for **linter-driven development** — workflows where quality gates (tests, linters, design review) guide your design instead of slowing you down.

## What's Inside

| | Plugin | Version | For |
|---|--------|---------|-----|
| 🐹 | [`go-linter-driven-development`](go-linter-driven-development/README.md) | 2.0.0 | Go |
| ⚛️ | [`ts-react-linter-driven-development`](ts-react-linter-driven-development/README.md) | 1.0.0 | TypeScript + React |

Plus the standalone rule documents the plugins grew out of:

- [`coding_rules.md`](coding_rules.md) — Go coding principles (types, testing, refactoring, anti-patterns)
- [`coding_rules_ts_react.md`](coding_rules_ts_react.md) — TypeScript + React principles

### Go plugin (v2 — rules as data)

The organising idea: **the rule is the unit, not the phase.** Each design principle lives exactly once, as data:

- **`rules/` R1–R9** — single source of truth: primitive obsession, self-validating types, storifying, helper placement, vertical slices, test-only interfaces, test placement, no globals, repo-brain documentation.
- **`skills/`** — six thin directional views that sequence and route into the rules (orchestrator, design, testing, refactoring, review, documentation).
- **`agents/`** — payload-fed isolated workers: parallel single-obsession `rule-hunter`s, an `overabstraction-skeptic` that tries to kill proposed extractions, and a `lint-fixer` that keeps the lint loop out of your conversation.
- **`commands/`** — `/go-ldd-autopilot`, `/go-ldd-quickfix`, `/go-ldd-analyze`, `/go-ldd-review`, `/go-ldd-status`, `/wire-repo-brain`.

Full architecture, workflow, and usage: [plugin README](go-linter-driven-development/README.md) · what changed between versions: [CHANGELOG](go-linter-driven-development/CHANGELOG.md).

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

1. Clone the repo and edit the plugin files (`rules/`, `skills/`, `agents/`, `commands/`).
2. Test locally by adding the checkout as a marketplace:
   ```
   /plugin marketplace add ./ai-coding-rules
   /plugin install go-linter-driven-development@ai-coding-rules
   ```
   After changes, uninstall/reinstall the plugin to pick them up.
3. For the Go plugin, follow its architecture contract — each fact lives once: rule content goes in `rules/`, worked case studies in `examples/`, skills only sequence and route. See the [plugin README](go-linter-driven-development/README.md#architecture-rules-as-data).
4. Open a PR; releases are tagged per plugin (e.g. [`go-ldd-v2.0.0`](https://github.com/buzzdan/ai-coding-rules/releases/tag/go-ldd-v2.0.0)).

## License

MIT
