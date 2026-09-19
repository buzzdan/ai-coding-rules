During the refactor of a K3s configuration function (`alignCIDRArgs`, originally 60
lines mixing string parsing, boolean flag tracking, and triplicated switch cases),
two booleans tracked related state:

```go
var (
    isClusterCIDRSet bool
    isServerCIDRSet  bool
)
// ... a parsing loop sets them ...
if isClusterCIDRSet && isServerCIDRSet {
    return // both set, nothing to do
}
```
