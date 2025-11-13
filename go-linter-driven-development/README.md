# Go Linter-Driven Development

**Stop fighting your linter. Let it guide you to better code.**

This Claude Code plugin turns Go development into a smooth, automated workflow where quality gates don't slow you down—they help you write cleaner code faster. Instead of manually running tests, fixing linter errors one by one, and wondering if your design is solid, this plugin orchestrates everything in parallel and tells you exactly what to fix and why.

### The Problem It Solves

You've been there: write some code, run tests (they pass!), run the linter... 15 errors. Fix those. Run again. More errors. Fix complexity here, function length there. Wonder if you're just playing whack-a-mole. Finally get it green, but is the design actually good?

**Traditional workflow:**
```
Write code → Tests (2 min) → Linter (1 min) → Fix → Linter again → Fix → Code review → Surprise design issues
Total: 15-20 minutes of back-and-forth
```

**With this plugin:**
```
Write code → Everything runs in parallel (2 min) → Intelligent report → Targeted fixes → Done
Total: 5-7 minutes, better results
```

The secret? **Intelligent combining.** When your linter says "complexity 18" and "function too long" at the same place, and the design reviewer says "mixed abstractions"—that's not 3 separate problems. It's one root cause. One strategic refactoring fixes all three.

## What's Included

**Six specialized skills** that work together:

1. **@linter-driven-development** - Meta-orchestrator for complete workflow
2. **@code-designing** - Domain type design and architecture planning
3. **@testing** - Testing principles and patterns
4. **@refactoring** - Linter-driven refactoring strategies
5. **@pre-commit-review** - Design validation (advisory)
6. **@documentation** - Feature documentation generation

**Two autonomous agents** for parallel quality analysis:

1. **quality-analyzer** - Orchestrates tests, linter, and code review in parallel; combines results intelligently
2. **go-code-reviewer** - Specialized design analysis for primitive obsession, mixed abstractions, and architectural issues

**Five slash commands** for quick access:

- `/go-ldd-autopilot` - Full workflow from design to commit
- `/go-ldd-quickfix` - Quality gates loop with auto-fix
- `/go-ldd-analyze` - Quality analysis only (read-only)
- `/go-ldd-review` - Final verification (read-only)
- `/go-ldd-status` - Show current progress

## TL;DR - Should I Use This?

**You should use this plugin if:**

✅ You're tired of manually running tests, then linter, then fixing issues one by one
✅ Your linter gives you 15 errors and you're not sure which to fix first
✅ You want your code to be maintainable, not just "working"
✅ You're using Go and want to follow best practices without memorizing them
✅ You want AI to handle the boring parts (quality gates) so you can focus on features

**This plugin might be overkill if:**

❌ You're writing quick scripts that won't be maintained
❌ Your project doesn't use `golangci-lint` and you don't plan to
❌ You prefer complete manual control over every single quality check

**What makes it special:**

- 🚀 **40-50% faster** than running quality gates sequentially
- 🧠 **Intelligent combining** - 10+ issues become 3-4 strategic fixes
- 🤖 **Zero configuration** - discovers your project setup automatically
- 🔄 **Auto-fix loop** - doesn't stop until all quality gates pass
- 📊 **Root cause analysis** - tells you WHY issues cluster together

## Why Linter-Driven Development?

### Code Written for Understanding, Not Just Execution

The philosophy: **If code takes more than 10-15 seconds to understand, it's too complex.**

Modern development involves two readers:
- **Humans** - Limited by working memory (4-7 items, Miller's Law)
- **AI** - Works on heuristics from clean, well-documented code

Clean, storified code with clear abstractions and documentation provides:
- **Lower cognitive load** → Faster human understanding
- **Better heuristics** → More accurate AI assistance

### The Three Pillars of Maintainability

Linter rules enforce objective quality standards:

**1. Cyclomatic Complexity ≤ 10**
- Counts independent execution paths through code
- Higher complexity = more places for bugs to hide
- Forces breaking down complex logic into testable units

**2. Cognitive Complexity ≤ 15**
- Measures human effort required to understand code
- Penalizes deeply nested structures and mixed abstractions
- Enforces "storified" functions that read like prose

**3. High Maintainability Index**
- Composite metric predicting long-term code health
- Reflects how easy code is to modify without breaking
- Studies show: maintenance costs grow exponentially with complexity

### How Linter Rules Drive Design

Beyond complexity metrics, linter rules enforce architectural decisions:

**`gochecknoglobals`** → Dependency injection instead of global state
**`gocognit`** → Extract functions, reduce nesting
**`gocyclo`** → Break switch statements into strategy patterns
**`funlen`** → Functions < 50 LOC, single responsibility
**`nestif`** → Max 2 nesting levels, use early returns

**The result**: Design decisions aren't subjective—they're driven by measurable quality metrics.

### Why This Matters

**For Humans:**
- Developers spend far more time reading code than writing it
- Lower complexity = faster onboarding, easier debugging, fewer errors
- Code reviews focus on design, not comprehension struggles

**For AI:**
- Clean abstractions provide better context for code generation
- Well-named types and functions improve AI suggestions
- Documentation and comments enhance AI understanding of intent

**For Teams:**
- Objective quality standards reduce bike-shedding
- Linter failures signal technical debt accumulation
- Consistent style across contributors

### The Workflow Philosophy

Instead of writing code then hoping it passes review, **let the linter guide refactoring**:

1. **Design** - Plan types around behavior (prevent primitive obsession)
2. **Implement** - Write tests, implement with full coverage
3. **Lint** - Run linter (cyclomatic, cognitive, maintainability checks)
4. **Refactor** - Let linter failures drive extraction into cleaner abstractions
5. **Review** - Validate design principles linters can't catch
6. **Commit** - Code is guaranteed maintainable by objective metrics

This plugin automates this workflow, ensuring every commit meets quality standards.

## Installation

**Step 1: Add the marketplace**
```
/plugin marketplace add buzzdan/ai-coding-rules
```

**Step 2: Install the plugin**
```
/plugin install go-linter-driven-development@ai-coding-rules
```

**Verify installation:**
```
/plugin list
```
Should show: `go-linter-driven-development (enabled)`

## Quick Start

**Good news:** Zero configuration required! The plugin is smart enough to discover your project's test and lint commands from `README.md`, `CLAUDE.md`, `Makefile`, or `Taskfile.yaml`. Just install and go.

### 🚀 The Easiest Way: Just Talk to It

Seriously, that's it. Just tell Claude what you want:

```
"implement step 1"
"ready to start coding"
"do the next task"
"execute the authentication feature"
```

The plugin recognizes these phrases and **automatically engages autopilot mode**. You don't need to remember commands or invoke anything special.

**What happens next (without you doing anything):**

1. 🔍 **Discovery** - Finds your test and lint commands
2. ⚡ **Parallel Analysis** - Runs tests, linter, and design review simultaneously (40-50% faster)
3. 🧠 **Intelligent Combining** - Identifies overlapping issues with root cause analysis
4. 🔧 **Auto-Fix Loop** - Applies strategic fixes, re-verifies, repeats until green
5. 📚 **Documentation** - Generates godoc and examples
6. ✅ **Commit Ready** - Presents summary with suggested commit message

You just implement your feature. The plugin handles quality gates.

### Want More Control? Use Slash Commands

If you prefer explicit commands over automatic detection, use these:

| Command | Perfect For | What It Does | Auto-Fix? |
|---------|------------|--------------|-----------|
| `/go-ldd-autopilot` | New feature from scratch | Full workflow: design → implement → fix → document → commit | ✅ Yes |
| `/go-ldd-quickfix` | Existing code needs cleanup | Skips implementation, just runs quality gates and fixes | ✅ Yes |
| `/go-ldd-analyze` | "What's wrong with my code?" | Analysis report only, no changes made | ❌ No |
| `/go-ldd-review` | Pre-commit sanity check | Quick verification: are we green? | ❌ No |
| `/go-ldd-status` | "Where are we?" | Shows current progress in workflow | N/A |

**Which one should I use?**

```bash
# Starting fresh? Full autopilot
/go-ldd-autopilot

# Code is written, just needs to pass linter/tests?
/go-ldd-quickfix

# Want to see what's wrong before deciding whether to fix?
/go-ldd-analyze

# About to commit, want one final check?
/go-ldd-review

# Lost track of where we are in a complex feature?
/go-ldd-status
```

**Pro tip:** Most of the time, you won't need these. Just say "implement X" and autopilot mode kicks in automatically.

### Need Just One Piece? Use Individual Skills

Sometimes you don't need the full workflow—just help with one specific thing:

```
# Planning phase? Get help designing types
"Use @code-designing to plan types for payment processing"

# Writing tests? Get expert guidance
"Use @testing to structure tests for UserService"

# Linter complaining about complexity? Get strategic refactoring help
"Use @refactoring to reduce complexity in HandleRequest"

# Want a second opinion on your design?
"Use @pre-commit-review to validate this code"

# Feature done, need documentation?
"Use @documentation to document the auth feature"
```

Think of skills as expert consultants you can call on demand. The full workflow uses them automatically, but you can invoke them individually when you need specific help.

## How It Works: Visual Overview

Here's the complete workflow from "I want to implement X" to commit-ready code:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Implementation Foundation                                      │
│                                                                          │
│  You write code (or say "implement step 1")                            │
│         ↓                                                               │
│  Plugin helps with design → tests → implementation                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 2: Parallel Quality Analysis (⚡ This is the magic)               │
│                                                                          │
│                    ┌──────────────────────┐                            │
│                    │  quality-analyzer    │                            │
│                    │       agent          │                            │
│                    └──────────────────────┘                            │
│                             │                                           │
│              ┌──────────────┼──────────────┐                          │
│              ↓              ↓               ↓                          │
│        ┌─────────┐    ┌─────────┐    ┌──────────────┐               │
│        │  Tests  │    │ Linter  │    │ go-code-     │               │
│        │ go test │    │golangci │    │ reviewer     │               │
│        └─────────┘    └─────────┘    └──────────────┘               │
│              │              │               │                          │
│              └──────────────┼───────────────┘                          │
│                             ↓                                           │
│              ┌────────────────────────────┐                           │
│              │ Intelligent Combining:     │                           │
│              │ • Find overlaps at file:line│                          │
│              │ • Root cause analysis       │                           │
│              │ • Priority ranking          │                           │
│              └────────────────────────────┘                           │
│                             ↓                                           │
│              📊 Combined Report with Fix Strategy                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 3: Auto-Fix Loop                                                  │
│                                                                          │
│  Apply highest priority fix → Re-verify in parallel → Next fix         │
│                   ↓                      ↓                              │
│              Still issues?          All green?                          │
│                   ↓                      ↓                              │
│            Loop continues           Exit to Phase 4                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────────┐
│ Phase 4: Documentation → Phase 5: Commit Ready ✅                       │
│                                                                          │
│  godoc + examples → Summary + suggested commit message                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### What Makes This Different: Intelligent Combining

Instead of dumping separate test/linter/review outputs, the quality-analyzer agent combines them intelligently:

**Without intelligent combining (traditional approach):**
```
❌ Linter says:
   • pkg/parser.go:45 - cognitive complexity 18 (limit: 15)
   • pkg/parser.go:45 - function length 58 lines (limit: 50)

❌ Code reviewer says:
   • pkg/parser.go:45 - mixed abstraction levels
   • pkg/parser.go:45 - defensive null checking pattern

You see: 4 separate problems to fix one by one
Reality: You might fix them separately, create inconsistent solutions
```

**With intelligent combining (this plugin):**
```
✨ quality-analyzer agent says:

┌─────────────────────────────────────────────────────┐
│ pkg/parser.go:45 - OVERLAPPING (4 issues)           │
│                                                      │
│ 🎯 ROOT CAUSE:                                      │
│ This function handles multiple responsibilities at  │
│ different abstraction levels (parsing, validation,  │
│ building result). The complexity and length issues  │
│ stem from doing too much. The defensive checking    │
│ and mixed abstractions are symptoms of the same     │
│ underlying problem.                                  │
│                                                      │
│ Impact: HIGH (4 issues resolved with one fix)       │
│ Complexity: MODERATE                                 │
│ Priority: #1 CRITICAL                                │
│                                                      │
│ 💡 Strategy: Apply STORIFYING pattern - extract     │
│    parseRawInput(), validateFields(), buildResult() │
└─────────────────────────────────────────────────────┘

Result: One strategic refactoring fixes all 4 issues at once
```

This is why the plugin turns **10+ scattered issues** into **3-4 strategic fixes**. You're not playing whack-a-mole anymore—you're fixing root causes.

### Smart Routing: The Plugin Adapts to Your Code

The quality-analyzer agent checks your code and decides what to do next based on what it finds:

```
🔍 Running analysis...

Status: TOOLS_UNAVAILABLE
  └─> "Looks like golangci-lint isn't installed. Here's how to install it..."

Status: TEST_FAILURE
  └─> "Tests are failing. Let's fix those first before worrying about quality."
      (Enters Test Focus Mode - nothing else matters until tests pass)

Status: ISSUES_FOUND
  └─> "Tests pass! Found 13 issues. Good news: 10 of them cluster into
       3 root causes. Let's fix those strategically."
      (Enters Auto-Fix Loop)

Status: CLEAN_STATE
  └─> "Everything's green! Tests pass, linter clean, design looks good.
       Let's document this and prepare for commit."
      (Skips directly to documentation)
```

The workflow isn't rigid—it adapts to what your code actually needs right now.

### Fast Iteration: Incremental Mode

The plugin is smart about re-analysis. After the initial full scan, it only re-checks files that changed:

```
🔄 Fix Loop in Action:

Iteration 1: Full analysis (8 files, 60 seconds)
  └─> Found 13 issues across 8 files
  └─> Applied fix to pkg/parser.go:45

Iteration 2: Incremental (1 file, 20 seconds)  ⚡ 3x faster
  ✅ Fixed: 4 issues from pkg/parser.go:45
  ⚠️ Remaining: 9 issues in other files
  🆕 New: 0 issues introduced
  └─> Applied fix to pkg/validator.go:23

Iteration 3: Incremental (1 file, 18 seconds)
  ✅ Fixed: 3 issues from pkg/validator.go:23
  ⚠️ Remaining: 6 issues
  🆕 New: 0 issues introduced
  └─> Continue...
```

No wasted time re-analyzing unchanged code. Fast feedback keeps you in flow state.

### Example: Quality Analysis Report

Here's what the quality-analyzer agent returns:

```
═══════════════════════════════════════════════════════
QUALITY ANALYSIS REPORT
Mode: FULL
Files analyzed: 8
═══════════════════════════════════════════════════════

📊 SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tests: ✅ PASS (coverage: 87%)
Linter: ❌ FAIL (5 errors)
Review: ⚠️ FINDINGS (8 issues: 0 bugs, 3 design, 4 readability, 1 polish)

Total issues: 13 from 3 sources

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OVERLAPPING ISSUES ANALYSIS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Found 3 locations with overlapping issues:

┌─────────────────────────────────────────────────────┐
│ pkg/parser.go:45 - function Parse                   │
│ OVERLAPPING (4 issues):                             │
│                                                      │
│ ⚠️ Linter: Cognitive complexity 18 (>15)           │
│ ⚠️ Linter: Function length 58 statements (>50)     │
│ 🔴 Review: Mixed abstraction levels                 │
│ 🔴 Review: Defensive null checking                  │
│                                                      │
│ 🎯 ROOT CAUSE:                                      │
│ Function handles multiple responsibilities at       │
│ different abstraction levels (parsing, validation,  │
│ building result).                                   │
│                                                      │
│ Impact: HIGH (4 issues) | Complexity: MODERATE      │
│ Priority: #1 CRITICAL                               │
└─────────────────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIORITIZED FIX ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Priority #1: pkg/parser.go:45 (4 issues, HIGH impact)
Priority #2: pkg/validator.go:23 (3 issues, HIGH impact)
Priority #3: pkg/handler.go:67 (2 issues, MEDIUM impact)

Isolated issues: 6 (fix individually)

Total fix targets: 3 overlapping groups + 6 isolated = 9 fixes

STATUS: ISSUES_FOUND
```

The orchestrator then invokes @refactoring skill to fix Priority #1, which resolves all 4 issues at once. After each fix, quality-analyzer re-runs in incremental mode to verify progress.

## How the Plugin Categorizes Issues

When reviewing your code, issues are grouped by urgency:

- 🔴 **Design Debt** - Will cause pain when extending (fix before commit recommended)
- 🟡 **Readability Debt** - Hard to understand now (improves maintainability)
- 🟢 **Polish Opportunities** - Minor improvements (nice to have)

This helps you decide what to tackle now vs. what can wait.

## The Design Principles Behind This

The plugin follows opinionated Go best practices:

**Design Philosophy:**
- **No primitive obsession** - String IDs? Make them types. Validates once, safe everywhere.
- **Vertical slices** - Group by feature (`user/service.go`, `user/repository.go`), not by layer (`services/`, `repositories/`)
- **Intent-revealing types** - Types should express business rules, not just data shapes

**Testing Philosophy:**
- **Test behavior, not implementation** - Use `pkg_test` package to only test public API
- **Real dependencies** - HTTP test servers, temp files, in-memory DBs. Mocks are a last resort.
- **100% coverage on leaf types** - Types with no dependencies should be bulletproof

**Refactoring Philosophy:**
- **Let the linter guide you** - Complexity errors? Extract functions. It's not subjective.
- **Storifying** - Top-level functions read like a story: `parseInput() → validate() → process()`
- **Early returns** - Reduce nesting, make the happy path obvious

These aren't arbitrary rules. They're patterns that consistently lead to maintainable code.

## What Happens After You Use This

After a few features built with this plugin, you'll notice:

1. **Your code reviews get faster** - Less "what does this do?" and more "should we handle X?"
2. **Onboarding is easier** - New team members understand code faster
3. **Bugs hide less** - Lower complexity = fewer places for bugs to lurk
4. **Refactoring becomes safer** - Good test coverage means you can change code confidently
5. **AI assistance improves** - Clean, well-documented code = better AI suggestions

The goal isn't just passing the linter. It's code that's a joy to work with six months from now.

## Updating

```
/plugin update go-linter-driven-development@ai-coding-rules
```

Or update through the plugin menu:
```
/plugin
```
Select "go-linter-driven-development" and choose "Update"

## Uninstalling

```
/plugin
```
Select "go-linter-driven-development" and choose "Uninstall"

## Need Help or Want to Contribute?

**Documentation:** Full details, examples, and advanced usage in the [main repository](https://github.com/buzzdan/ai-coding-rules)

**Found a bug or have an idea?** [Open an issue on GitHub](https://github.com/buzzdan/ai-coding-rules/issues) - I'd love to hear from you!

**Want to contribute?** PRs welcome! Whether it's fixing typos, adding examples, or improving the skills themselves.

## License

MIT - Use it however you want!

---

**Happy coding!** May your linter always be green and your complexity always be low. 🚀
