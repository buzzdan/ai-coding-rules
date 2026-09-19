1. **Fat function** — 48 lines, cyclomatic complexity 12, cognitive complexity 18:
   collection, validation, and config mutation crammed into one body.
2. **Mixed abstraction levels (R3)** — type assertions and `To4()` bit-fiddling in
   the same body as the business decision "is this configuration valid".
3. **Boolean flags tracking loop state** — `addrIP4Added`/`addrIP6Added` are set
   inside the loop and read after it: the classic signature of a collection type
   waiting to absorb the loop.
4. **Comments naming blocks** — `// validate IP6`, `// already added. skip`: each is
   an extraction order (R3), a function name written as prose.
5. **Dishonest names** — `parseIP4`/`parseIP6` mutate `c.IP4`/`c.IP6`; "parse"
   promises read-only. (Note the real-world bug it helped hide: the before code logs
   `Str("ip4", c.IP6)` — a copy-paste slip that a smaller, honest function would
   have made glaring.)
6. **No leaf types (R1)** — all logic lives on the big `Config`, so nothing is
   testable without constructing a `net.Interface` scenario.
