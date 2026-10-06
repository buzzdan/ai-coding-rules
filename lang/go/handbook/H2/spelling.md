
> **In Go:** wrap with `fmt.Errorf("parse port %q: %w", name, err)`; inspect only with
> `errors.Is` and `errors.As`, never by string; a sentinel `var ErrX = errors.New(...)`
> is exported only when a caller decides on it.

**Review:** Is any error both logged and returned, or inspected by string?
