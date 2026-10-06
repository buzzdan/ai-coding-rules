  ```typescript
  // ❌ re-validates what Host already guarantees
  export function createAddress(host: Host, port: Port): Address {
    if (host.name === '') { // Host owns this
      throw new Error('host required')
    }
    return { host, port }
  }

  // ✅ trusts composed self-validating types — nothing left to check, nothing to throw
  export interface Address {
    readonly host: Host
    readonly port: Port
  }
  // an object literal is its constructor: both parts arrive valid, so no factory is owed
  ```
