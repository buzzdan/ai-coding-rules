---
type: file_exists
path: 'internal/*/*[sS][mM][sS]*.go'
---
The sms behavior landed in its own file one level under internal/ — a feature
slice (`internal/sms/sms.go`, Option A) or a file in an existing package
(`internal/alerting/sms_channel.go`). The glob tolerates the package name but
not depth: filepath.Glob has no `**`, so `internal/alerting/sms/sms.go` would
fail here while postcheck.sh's `find`-based NOTE still reports it. The plan
asked for "file_exists for the new type in the expected package"; the obvious
`internal/*/channel*.go` is useless because models/channel.go pre-exists, so the
sms file is the assertable new-type file. This is the grader most likely to
produce a false failure — read it together with postcheck's placement NOTE.
