```typescript
interface CIDRConfig {
  clusterCidrSet: boolean
  serviceCidrSet: boolean
}
```

`config.clusterCidrSet` reads exactly as well as `config.clusterCidr.isSet()`, at
zero ceremony. Acceptable when mutation discipline isn't a concern (small, disciplined
surface; short-lived value).
