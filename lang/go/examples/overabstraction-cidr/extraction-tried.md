```go
// CIDRPresence — a wrapper that adds NO value
type CIDRPresence bool

const (
    cidrPresent CIDRPresence = true
)

func (p CIDRPresence) IsSet() bool {
    return bool(p) // just unwraps the bool!
}

type CIDRConfig struct {
    ClusterCIDR CIDRPresence // wrapped bool
    ServiceCIDR CIDRPresence // wrapped bool
}

func (c CIDRConfig) AreBothSet() bool {
    return c.ClusterCIDR.IsSet() && c.ServiceCIDR.IsSet()
}
```
