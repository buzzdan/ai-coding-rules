  ```typescript
  // ❌ relies on callers to validate
  export interface Config {
    host: string // every caller must remember: if (host === '') ...
    port: number
  }

  // ✅ owns its own validation
  export interface Config {
    readonly host: string
    readonly port: number
  }

  export function parseConfig(host: string, port: number): Config {
    if (host === '') {
      throw new Error('host required')
    }
    if (!Number.isInteger(port) || port <= 0 || port > 65535) {
      throw new Error('invalid port')
    }
    return { host, port }
  }
  ```
