When the need is controlled mutation rather than validation or logic, private fields
with read-only accessors deliver compiler-enforced safety without a wrapper:

```go
// CIDRConfig — which CIDR configurations are present.
// Private fields: can only be set by ParseCIDRConfig.
type CIDRConfig struct {
    clusterCIDRSet bool
    serviceCIDRSet bool
}

func (c CIDRConfig) ClusterCIDRSet() bool { return c.clusterCIDRSet }
func (c CIDRConfig) ServiceCIDRSet() bool { return c.serviceCIDRSet }

func (c CIDRConfig) AreBothSet() bool {
    return c.clusterCIDRSet && c.serviceCIDRSet
}
```

Why this beat the wrapper:

- **Same safety** — the compiler enforces that only the parser (in the same package)
  can set the values; external code gets read-only access.
- **4 fewer lines** than the `CIDRPresence` approach.
- **Same readability** — `ClusterCIDRSet()` is just as clear as `ClusterCIDR.IsSet()`.
- **No wrapper ceremony** — the fields are what they are: bools.
