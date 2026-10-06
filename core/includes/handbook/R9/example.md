```text
# ❌ restates the signature; the reader learned nothing
{{.CommentPrefix}} parsePort parses a port from a name and a number.
parsePort(name, number)

# ✅ says why the type exists and where the long story lives
{{.CommentPrefix}} parsePort is the only way to obtain a Port, so no downstream code re-checks the
{{.CommentPrefix}} range: an out-of-range port cannot exist. Selection policy: docs/management-port.md.
parsePort(name, number)
```

> **Spelling:** the {{.DocComment}} is the language's documentation form: `///` or
> `//` line comments, a `/** */` block, a docstring. A summary line the tooling
> requires states the contract and is never a restatement finding; the lines after
> it earn their place by saying *why*, in one to five lines. Anything longer moves to
> `docs/<feature>.md` with a line that points there. A comment that restates the code
> is deleted, and a private symbol carries none by default.
