---
type: guide
description: how to start working with a linter-driven-development plugin — from the one-line prompt that runs the whole workflow, through reviewing and fixing code you already wrote, to feeding it a plan, running it from a subagent, and sharing a repository between two language plugins
---
# Quick Start

The scenarios below go from the easiest to the most involved. Start with the first
one. Move down only when your situation needs it.

Commands are shown for the Go plugin. Every plugin has the same commands with its
own prefix. A repository with two languages installs two plugins; section 7 says how
they share it.

| Plugin | Prefix | Example |
|---|---|---|
| go-linter-driven-development | `/go-ldd-` | `/go-ldd-autopilot` |
| python-linter-driven-development | `/py-ldd-` | `/py-ldd-autopilot` |
| ts-react-linter-driven-development | `/tsr-ldd-` | `/tsr-ldd-autopilot` |
| linter-driven-development (any other language) | `/ldd-` | `/ldd-autopilot` |

## Install once

```
/plugin marketplace add buzzdan/ai-coding-rules
/plugin install go-linter-driven-development@ai-coding-rules
```

No configuration. The plugin finds your test and lint commands in the Taskfile,
Makefile, README or CLAUDE.md. The first time the workflow starts, Claude asks for
permission to use the skill. Choose "Yes, and don't ask again for this directory".

## 1. A feature or a bug fix, from zero

Say what you want in plain words:

```
/go-ldd-autopilot fix the retry bug in client.go
/go-ldd-autopilot add rate limiting to the upload handler
```

The same words without the command also work: any request to implement, fix, add or
refactor code starts the workflow on its own. The command makes it explicit. Then:

1. **Design.** You get a DESIGN PLAN: the types, the behaviors, the tests. Read it.
   This is the cheapest moment to change direction. Say OK.
2. **Implement.** The plugin runs alone: a preparatory refactor when needed, then one
   failing test, the code that passes it, and a lint pass, per behavior. Do not
   interrupt. `/go-ldd-status` tells you where it is.
3. **Review.** You get an advisory report. Fix 🐛 Bugs now. Fix 🔴 Design Debt
   before the commit. 🟡 and 🟢 are your call: say "fix all" or "defer the yellow
   ones".
4. **Ship.** Documentation and a commit. You get the hash.

A bug fix differs only in the first step: the plan is short, and the first failing
test is the reproduction.

## 2. Review before a commit or a pull request

```
/go-ldd-review
```

Read-only. It runs the rule hunters, the over-abstraction skeptic and the comment
critic over a diff and reports 🐛 Bugs, 🔴 Design Debt, 🟡 Readability Debt and
🟢 Polish. It never edits and never commits. The scope is the first of these that
applies:

- **A path**: `/go-ldd-review ./pkg/foo/` reviews those files.
- **A dirty tree**: your uncommitted changes. This is the pre-commit review.
- **A clean tree**: every change since the branch left its base, the diff a pull
  request shows. This is the branch review. Check out the branch, commit everything,
  run the command.

It reviews code against the rules and reports bugs. It does not read a pull request's
description and does not post comments on it. To fix what it finds, run
`/go-ldd-quickfix` over the same scope.

## 3. Code you already wrote

```
/go-ldd-quickfix
```

One command, until green: tests, lint, the review from the previous section, the
fixes, and the commit. It skips design and the test-first loop. The scope follows
the same rules as the review: a path fixes that package, a dirty tree fixes your
changes, a clean tree fixes the branch. It never touches the whole repository
unless you pass `--all`.

The commit is part of the command. Nothing to run before or after it.

## 4. A repository that never ran the plugin

```
/go-ldd-analyze --all
```

Read-only. Shows the size of the debt before you fix anything. Then fix one package
at a time with `/go-ldd-quickfix ./pkg/x/`. A whole-repository `--all` fix is a long
run; start it on purpose, not by accident.

## 5. You already have a plan

Many people plan first, with plan mode, a brainstorming skill or a design document.
Keep doing that. The plan and the DESIGN PLAN answer different questions:

- **Your plan says what**: the behaviors, the scope, the acceptance criteria.
- **The DESIGN PLAN says how the code is shaped**: the types, their constructors,
  the package layout, where each helper lives.

Save the plan outside git, for example under `.planning/` or `~/.claude/plans/`.
Then start the workflow and point at it:

```
implement .planning/rate-limit.md with ldd
```

The design phase reads your plan and skips the questions it already answers. Check
the DESIGN PLAN against your plan before you approve it. Your plan is the authority.
A DESIGN PLAN line that contradicts a sentence of your plan is a conflict to settle
now, before the first test is written.

Things to watch:

- **Your plan already says how.** The design phase still produces its own shape. When
  the two disagree, pick one. Do not let both ship half.
- **Your plan has many steps.** One run of the workflow is one coherent set of
  behaviors that commits green. Run it once per step, not once over the whole plan.
  Each step gets its own review and its own commit.
- **Another skill wants to execute the plan.** Two drivers on one task collide. For
  code steps, name the plugin: "execute step 3 with ldd".
- **The plan delivers no new behavior** ("clean up module X"). There is no failing
  test to write. The workflow runs the refactoring skill over the files you name,
  then lint, review and ship.

## 6. Running the plugin from a subagent

Some plans are executed by subagents, one per step, often on a cheaper model. The
plugin works there, with one limit: **a subagent cannot spawn subagents.** The
workflow spawns agents in three places: the preparatory refactor's skeptic, the full
lint pass and the review. Inside a subagent those phases lose their isolated
context. The review degrades to a self-review, which is weaker: a fresh context is
what makes the review's findings trustworthy.

Split the work by where agents can be spawned:

**In the subagent**: design and implementation. This is the test-code-lint loop, the
token-heavy part. A cheaper model does it well. Paste this into each plan step:

```
Implementation: invoke the skill go-linter-driven-development:linter-driven-development.
Run the design and implementation phases only. The DESIGN PLAN is pre-approved by
this step; do not wait for user OK. Do not spawn agents, do not run the lint, review
or ship phases, do not commit. Report the files touched and the behaviors delivered.
```

**In the main session**, after each step returns:

```
/go-ldd-quickfix <files from the report>
```

Lint, review, fixes and the commit, with the agents in their own contexts. Give the
commit one owner: the step text above tells the subagent not to commit, and your
plan executor must not commit either, because this command does.

At the end of the whole plan, with a clean tree, `/go-ldd-review` runs the branch
review from section 2.

## 7. A repository with more than one language

A Go backend and a TypeScript + React frontend in one repository: install both
plugins. They live side by side; nothing in their names collides.

```
/plugin install go-linter-driven-development@ai-coding-rules
/plugin install ts-react-linter-driven-development@ai-coding-rules
```

Each plugin sees only its own files. The Go plugin scopes, lints and reviews `*.go`
files; the TypeScript plugin scopes `*.ts` and `*.tsx` files. A command never
touches the other language. The consequences:

- **Use the prefixed command, not the plain prompt.** Both plugins match a mixed
  repository, so a plain "fix the retry bug" has two candidates. The prefix leaves
  no doubt:

  ```
  /go-ldd-autopilot fix the retry bug in the API client
  /tsr-ldd-autopilot add the upload progress bar
  ```
- **Review the branch twice.** On a clean tree, `/go-ldd-review` reviews the
  backend half of the branch and `/tsr-ldd-review` the frontend half. The same for
  `/go-ldd-quickfix` and `/tsr-ldd-quickfix`: each fixes and commits its own files.
- **A feature that crosses the boundary is two slices.** Agree on the contract first,
  the endpoint and its payload, in your plan. Then run the backend slice with the Go
  plugin and the frontend slice with the TypeScript plugin, each with its own review
  and commit. One plan step per language keeps the subagent flow from section 6
  unchanged.
- **Start where the markers are.** Each plugin looks for its project marker, the Go
  module file or a package manifest that names React, in the working directory or a
  parent. When
  the backend and the frontend live in sibling directories, open the session in the
  directory you work on, or add it to the session, so the plugin finds its marker.
- **Wire the documentation once.** Both plugins offer `/wire-repo-brain`. It wires
  the repository's documentation network, not a language. Run it from either.

## Rules of thumb

- Let a phase finish. Stopping in the middle of implementation leaves a tree that is
  half green.
- The review is advisory. It never blocks a commit. You decide what to fix.
- Reshape before a big change: `/go-ldd-prepare "<the change>"` refactors what the
  change will touch, so the change itself lands by adding code, not by rewriting it.
- One expert at a time is fine: "use the code-designing skill for the payment
  types", "use the refactoring skill on the request handler", "use the testing skill
  to structure the tests for the client".
