```go
// ❌ the caller's slice is now the type's slice; a later append bypasses the constructor
func NewPorts(items []Port) Ports { return Ports{items: items} }
func (ps Ports) Items() []Port    { return ps.items }

// ✅ copy on the way in; hand out a copy or an iterator on the way out
func NewPorts(items []Port) Ports { return Ports{items: slices.Clone(items)} }
func (ps Ports) All() iter.Seq[Port] { return slices.Values(ps.items) }
```

> **In Go:** slices and maps are references into shared backing storage, so a
> constructor clones what it is given and a query never returns the field itself.
