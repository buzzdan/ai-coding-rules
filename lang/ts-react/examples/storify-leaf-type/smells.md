1. **Fat function** — 33 lines, cognitive complexity 17 (`sonarjs/cognitive-complexity`
   fires at the house threshold of 15), cyclomatic complexity 10 at
   `sonarjs/cyclomatic-complexity`'s ceiling, nesting depth 3: collection,
   validation, and config mutation crammed into one body.
2. **Mixed abstraction levels (R3)** — `a.scope`/`a.family` discrimination of the
   reported address in the same body as the business decision "is this
   configuration valid".
3. **Boolean flags tracking loop state** — `addrIp4Added`/`addrIp6Added` are set
   inside the loop and read after it: the classic signature of a collection type
   waiting to absorb the loop.
4. **Comments naming blocks** — `// validate IP6`, `// already added. skip`: each is
   an extraction order (R3), a function name written as prose.
5. **Dishonest names** — `parseIp4`/`parseIp6` mutate `config.ipv4`/`config.ipv6`;
   "parse" promises read-only. (Note the real-world bug it helped hide: the before
   code logs `config.ipv6` under "set IP4" — a copy-paste slip that a smaller, honest
   function would have made glaring.)
6. **No leaf types (R1)** — all logic runs against the whole `Config` draft, so
   nothing is testable without constructing a `Config` and a `ReportedInterface`
   scenario.
