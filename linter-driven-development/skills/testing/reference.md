# Testing Reference

This plugin carries no test-harness catalogue. The patterns the testing skill names —
an in-memory harness, a fake server with a DSL, a subprocess-driven binary
dependency, black-box system tests — are described in the skill itself; how each is
spelled follows the repository's language and its test framework.

Before inventing a harness, read the repository's own test utilities: the directory
its tests already import helpers from, its fixtures and its assertion style. Match
them. Never introduce a second test framework or assertion library.

The Go plugin's catalogue of worked harnesses (in-process HTTP servers, in-memory
brokers, embedded databases, test containers) lives in its own `skills/testing/`
reference and examples; a language binding of this core carries the same catalogue
in its language.
