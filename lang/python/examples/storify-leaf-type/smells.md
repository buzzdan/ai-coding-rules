1. **Fat function** — 40 lines, cyclomatic complexity 12 (ruff `C901` at the default
   threshold), twelve branches (`PLR0912`): collection, validation, and config
   mutation crammed into one body.
2. **Mixed abstraction levels (R3)** — `ipaddress.ip_address` parsing and
   `ip.version` checks in the same body as the business decision "is this
   configuration valid".
3. **Boolean flags tracking loop state** — `addr_ip4_added`/`addr_ip6_added` are set
   inside the loop and read after it: the classic signature of a collection type
   waiting to absorb the loop.
4. **Comments naming blocks** — `# validate IP6`, `# already added. skip`: each is
   an extraction order (R3), a function name written as prose.
5. **Dishonest names** — `_parse_ip4`/`_parse_ip6` mutate `self.ip4`/`self.ip6`;
   "parse" promises read-only. (Note the real-world bug it helped hide: the before
   code logs `self.ip6` under "set IP4" — a copy-paste slip that a smaller, honest
   function would have made glaring.)
6. **No leaf types (R1)** — all logic lives on the big `Config`, so nothing is
   testable without constructing an `Interface` scenario.
