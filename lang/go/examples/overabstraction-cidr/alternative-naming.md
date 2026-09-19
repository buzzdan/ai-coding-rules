```go
type CIDRConfig struct {
    ClusterCIDRSet bool
    ServiceCIDRSet bool
}
```

`config.ClusterCIDRSet` reads exactly as well as `config.ClusterCIDR.IsSet()`, at
zero ceremony. Acceptable when mutation discipline isn't a concern (small, disciplined
surface; short-lived value).
