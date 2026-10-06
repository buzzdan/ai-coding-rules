```typescript
// CIDRPresence — a wrapper that adds NO value
class CIDRPresence {
  constructor(private readonly value: boolean) {}

  isSet(): boolean {
    return this.value // just unwraps the boolean!
  }
}

const CIDR_PRESENT = new CIDRPresence(true)

class CIDRConfig {
  clusterCidr: CIDRPresence = CIDR_PRESENT // wrapped boolean
  serviceCidr: CIDRPresence = CIDR_PRESENT // wrapped boolean

  areBothSet(): boolean {
    return this.clusterCidr.isSet() && this.serviceCidr.isSet()
  }
}
```
