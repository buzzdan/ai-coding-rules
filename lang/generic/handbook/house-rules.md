The examples above are pseudocode: the shape of each rule, with the language's
spelling named in the note beneath it. Two rules exist because no binding knows this
repository's language; everything else that would be a house rule here is the
repository's own convention, read before the first edit.

### A1 — The repository's tooling is the tooling

Test and lint run through the commands the repository already defines: its Taskfile,
Makefile, package scripts or CI. A linter, test framework, formatter or type checker
the repository does not use is never installed or run; a repository with no linter is
a finding to raise, not a gap to fill in a feature PR. A repository in several
languages is worked one language at a time.

**Review:** Does the diff add a tool, dependency or configuration file the repository did not already use?

### A2 — Spell the shape in the repository's idiom

Every rule fixes a shape, and the move names are the same in every language; the
spelling is not. Absence, failure, visibility, the doc form, the spawn and the join
each have one form the repository already uses, and the fix arrives in that form: a
result type where the code returns results, an exception where it raises, an optional
where it declares one. An idiom carried in from another language, a sentinel where the
language has optionals, a checked-error pair where it throws, a class hierarchy where a
dispatch table is the norm, is a finding even when the rule it serves is satisfied.

**Review:** Does the diff spell a fix in another language's idiom where this one has its own form?
