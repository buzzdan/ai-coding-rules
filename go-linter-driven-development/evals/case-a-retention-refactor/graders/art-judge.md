---
type: llm
criteria: The retention concept now lives in one box with a name, and the code that uses it reads as a story of intent rather than a ledger of parsing and range checks.
focus: { source: files, paths: [internal/snapshot/policy.go, internal/snapshot/config.go] }
---
Glance at the two files as a reader who has never seen them. Judge the shape,
not the mechanics (tests and lint are graded elsewhere).

PASS only if all four hold, and quote the line that convinces you for each:

1. **One box.** "Retention" is a named thing — a type such as `Retention` or
   `RetentionDays` with its parsing and its 1–365 day rule inside it (a
   constructor or `Parse…` that returns `(T, error)`), and nothing outside
   that box re-parses `"d"` suffixes or re-checks the range. A bare
   `parseRetentionDays(raw) (int, error)` helper shared by both callers is a
   dedupe, not a box: FAIL.
2. **Names speak intent.** The pruning loop asks the retention something in
   domain words — `retention.Expired(age)`, `Covers(createdAt, now)`,
   `Allows(sn, now)` or similar — instead of comparing `age > days`. Method
   names that describe mechanics (`check`, `validate`, `getDays`) are FAIL.
3. **One altitude per function.** `applyPolicy` (or its successor) reads
   top-down as: obtain the retention, collect what it has expired, return —
   with no arithmetic, `strconv`, `strings` or unit conversion in that body.
4. **No leftover ceremony.** No `0` sentinel meaning "unset", no defensive
   re-check comment, no comment left where the name now says it.

FAIL if either file still contains `strconv.Atoi(strings.TrimSuffix(` at a
call site outside the retention type, or `days <= 0 || days > 365` in more
than one place.
