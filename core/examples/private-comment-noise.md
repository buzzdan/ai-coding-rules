# Comment Noise Case: Nine Private Helpers, Nine Comments

Demonstrates: R9 (comment policy — the visibility default)
{{include "examples/language-note.md"}}
A real 143-line file from a JSON-RPC-over-HTTP client (anonymized), written by an
LLM flow before the visibility default existed. It detects which codec decoded a
reply body: JSON, or the client's configured non-JSON codec (msgpack). Every one
of its nine {{.Unexported}} symbols carries a comment; the file has more comment lines
than code lines. Each comment, judged alone, "delivers a toolbox value". The file
as a whole is unreadable — a human reviewer of a sibling PR called the style
"utterly lacking empathy for the reader".

This is the case law for R9's visibility default: **{{.Unexported}} symbols get no
comment; the special case is one line carrying a very high-value toolbox item.**

## The before — representative excerpts

{{include "examples/private-comment-noise/before.md"}}

## The verdicts

All nine symbols are {{.Unexported}}, so the question is existence, not size:

{{include "examples/private-comment-noise/verdicts.md"}}

## The after

{{include "examples/private-comment-noise/after.md"}}

## The lesson

The tier budget caps how big a comment can be; only the visibility default
decides whether it should exist at all. Before this case, "Helper: 0–1 lines"
read as permission, and a writer in fill-the-menu mode gave every private symbol
its tier maximum — nine comments, each locally justified, jointly unreadable.
The default for {{.Unexported}} symbols is **zero**: the name is the documentation,
and a name that needs a comment wants a rename or an extraction first. The
special case is **one line carrying a very high-value toolbox item** — an
ordering constraint, an external library quirk, the WHY of a magic number, the
package's one real policy. If a private symbol seems to need more than that one
line, the knowledge belongs to the exported symbol that uses it, the package
doc, or the feature doc.
