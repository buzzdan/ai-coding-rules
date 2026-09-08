---
type: llm
criteria: The file reads like art — ProcessHeartbeat tells the story in domain sentences, each concept it used to inline now has its own well-named box, and the names make the old comments unnecessary.
focus: { source: file, path: internal/services/device_service.go }
---
Glance at the whole file as a first-time reader. The single-altitude grader
checks the ProcessHeartbeat body mechanically; you judge whether the result is
something a reviewer would call beautiful rather than merely split up.

PASS only if all five hold, quoting the convincing line for each:

1. **The story.** `ProcessHeartbeat` reads top-down as five or six named
   chapters — parse the heartbeat, find or register the device, apply the
   status transition, notify if it went down, score, persist — and a reader
   can predict each helper's job from its name alone.
2. **Concepts have boxes.** The wire line became a value (`Heartbeat`,
   `HeartbeatLine`) with its own parser; status is a type with named
   constants and behavior (`Status`, `IsDown()`, `Score()` or `Weight()`),
   not string literals compared inline; the retry/backoff and the
   tenant/region rules live in named helpers or types rather than in the
   body.
3. **Names are domain words, not mechanics.** No `helper`, `process2`,
   `handleRest`, `doTags`, `step3`, `tmp`, `parts`. Method names read as
   verbs on nouns the operator would recognize (`markDown`, `notifyDown`,
   `transition`, `persist`).
4. **Comments earned their place.** The `// parse the line`,
   `// look up or create device`, `// transitions` block markers are gone
   because the calls now say it. Comments that remain state a why or a
   contract, not a what.
5. **Nothing ugly hid elsewhere.** The `goto`, the labeled `continue`, the
   five-value return and the `time.Sleep` retry did not just move into a
   helper unchanged. Skim every function: a helper that is the old body
   with a new name is FAIL.

FAIL outright if `goto`, a `//nolint:gocognit` on `ProcessHeartbeat`, or a
helper named with a number or `helper` survives.
