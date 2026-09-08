---
type: llm
criteria: The three values that always travel together (host, port, TLS) became one named thing that owns its own questions, and the client reads as a story of what it does, not how it assembles strings.
focus: { source: file, path: internal/transport/client.go }
---
Glance at the file as a first-time reader. Judge shape and naming; tests and
lint are graded elsewhere.

PASS only if all four hold, quoting the convincing line for each:

1. **One box.** A named type such as `Endpoint`, `Address` or `Target` holds
   host, port and the TLS flag, is built through a constructor that owns the
   port-range rule once, and answers its own questions: the scheme
   (`Scheme()`), the URL for a path (`URL(path)`), the health URL, and the
   dial address. Free functions still taking `(host string, port int, tls
   bool)` are FAIL. Folding the fields into `*Client` methods that still
   branch on `c.tls` for the scheme in each method is a dedupe, not a box:
   FAIL.
2. **The scheme is decided once.** `"https"` and `"http"` appear together in
   exactly one place, ideally as a small enum or a method on the endpoint.
   Two `if tls { scheme = "https" }` blocks anywhere is FAIL.
3. **Names speak intent.** `Get`, `Ping`, `HealthURL` bodies read as
   sentences — `c.endpoint.URL(path)`, `c.endpoint.Dial(ctx)` — with no
   `fmt.Sprintf("%s://%s:%d…")` assembly inside them.
4. **No leftover ceremony.** The port-range check appears once (in the
   constructor); `dial` no longer re-validates a port that cannot be
   invalid; comments that restated names are gone or now state a contract.

Bonus, not required: if `Ping` on a TLS endpoint now performs the handshake
(`Handshake`) before closing, note it; the original silently skipped it.
