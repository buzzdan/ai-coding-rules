```go
// ❌ restates the signature; the reader learned nothing
// ParsePort parses a port from a name and a number.
func ParsePort(name string, n int32) (Port, error)

// ✅ says why the type exists and where the long story lives
// ParsePort is the only way to obtain a Port, so no downstream code re-checks the
// range: an out-of-range port cannot exist. Selection policy: see docs/management-port.md.
func ParsePort(name string, n int32) (Port, error)
```

> **In Go:** a godoc comment is one to five lines and says *why*; anything longer moves
> to `docs/<feature>.md` with a `See docs/<feature>.md` line. A package gets a
> package comment explaining its purpose, in `doc.go` when it earns more than a few
> lines. A comment that restates the code is deleted.
